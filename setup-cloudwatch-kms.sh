#!/bin/bash
set -e

# -------------------------
# CONFIG (แก้ตามของคุณ)
# -------------------------
REGION="us-east-1"
ACCOUNT_ID="111122223333"
LOG_GROUP="MY-LOG-GROUP"
OLD_KEY_ARN=""   # ถ้าไม่มี old key ให้เว้นว่าง

# -------------------------
# 1. Create KMS Key
# -------------------------
echo "🔑 Creating new KMS Key..."
NEW_KEY_JSON=$(aws kms create-key --description "Key for CloudWatch Logs encryption" --region $REGION)
NEW_KEY_ARN=$(echo $NEW_KEY_JSON | jq -r '.KeyMetadata.Arn')
NEW_KEY_ID=$(echo $NEW_KEY_JSON | jq -r '.KeyMetadata.KeyId')

echo "✅ Created KMS Key: $NEW_KEY_ARN"

# -------------------------
# 2. Generate new policy file
# -------------------------
cat > policy.json <<EOL
{
  "Version": "2012-10-17",
  "Id": "key-default-1",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::$ACCOUNT_ID:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "AllowCloudWatchLogsUseKey",
      "Effect": "Allow",
      "Principal": {
        "Service": "logs.$REGION.amazonaws.com"
      },
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:Describe*"
      ],
      "Resource": "*",
      "Condition": {
        "ArnLike": {
          "kms:EncryptionContext:aws:logs:arn": "arn:aws:logs:$REGION:$ACCOUNT_ID:log-group:$LOG_GROUP"
        }
      }
    }
  ]
}
EOL

# -------------------------
# 3. Apply policy to new key
# -------------------------
echo "📌 Attaching policy to new key..."
aws kms put-key-policy \
  --key-id $NEW_KEY_ID \
  --policy-name default \
  --policy file://policy.json \
  --region $REGION

echo "✅ Policy attached."

# -------------------------
# 4. Associate KMS key with log group
# -------------------------
echo "🔗 Associating key with CloudWatch log group..."
aws logs associate-kms-key \
  --log-group-name $LOG_GROUP \
  --kms-key-id $NEW_KEY_ARN \
  --region $REGION

echo "✅ Log group is now encrypted with KMS Key."

# -------------------------
# 5. (Optional) Update old key for decrypt
# -------------------------
if [ ! -z "$OLD_KEY_ARN" ]; then
  echo "⚡ Adding Decrypt permission to old key..."
  
  aws kms get-key-policy \
    --key-id $OLD_KEY_ARN \
    --policy-name default \
    --output text \
    --region $REGION > old-policy.json

  # Insert Decrypt statement
  cat > old-decrypt.json <<EOL
{
  "Effect": "Allow",
  "Principal": {
    "Service": "logs.$REGION.amazonaws.com"
  },
  "Action": [
    "kms:Decrypt"
  ],
  "Resource": "*"
}
EOL

  # Merge manually (jq merge)
  jq '.Statement += [input]' old-policy.json old-decrypt.json > merged-policy.json

  aws kms put-key-policy \
    --key-id $OLD_KEY_ARN \
    --policy-name default \
    --policy file://merged-policy.json \
    --region $REGION

  echo "✅ Old key updated for Decrypt access."
fi

echo "🎉 DONE! CloudWatch Logs encryption setup completed."
