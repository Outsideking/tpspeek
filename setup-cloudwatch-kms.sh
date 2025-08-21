#!/bin/bash
set -euo pipefail

REGION="${REGION:-ap-southeast-2}"
ACCOUNT_ID="${ACCOUNT_ID:-409661147964}"
LOG_GROUP="${LOG_GROUP:-MY-LOG-GROUP}"
OLD_KEY_ARN="${OLD_KEY_ARN:-}"

echo "Creating KMS key..."
NEW_KEY_JSON=$(aws kms create-key --description "CW Logs key" --region "$REGION")
NEW_KEY_ARN=$(echo "$NEW_KEY_JSON" | jq -r '.KeyMetadata.Arn')
NEW_KEY_ID=$(echo "$NEW_KEY_JSON" | jq -r '.KeyMetadata.KeyId')

aws kms create-alias --alias-name alias/tpn-cw-logs --target-key-id "$NEW_KEY_ID" --region "$REGION" || true

cat > policy.json <<EOF
{
  "Version": "2012-10-17",
  "Id": "key-default-1",
  "Statement": [
    {
      "Sid": "EnableRoot",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::${ACCOUNT_ID}:root" },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "AllowCloudWatchLogsUseKey",
      "Effect": "Allow",
      "Principal": { "Service": "logs.${REGION}.amazonaws.com" },
      "Action": ["kms:Encrypt","kms:Decrypt","kms:ReEncrypt*","kms:GenerateDataKey*","kms:Describe*"],
      "Resource": "*",
      "Condition": {
        "ArnLike": {
          "kms:EncryptionContext:aws:logs:arn": "arn:aws:logs:${REGION}:${ACCOUNT_ID}:log-group:${LOG_GROUP}"
        }
      }
    }
  ]
}
EOF

aws kms put-key-policy --key-id "$NEW_KEY_ID" --policy-name default --policy file://policy.json --region "$REGION"

aws logs create-log-group --log-group-name "$LOG_GROUP" --region "$REGION" 2>/dev/null || true
aws logs associate-kms-key --log-group-name "$LOG_GROUP" --kms-key-id "$NEW_KEY_ARN" --region "$REGION"

if [ -n "$OLD_KEY_ARN" ]; then
  echo "Granting Decrypt on OLD key..."
  cat > old-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Id": "key-default-1",
  "Statement": [
    {
      "Sid": "EnableRoot",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::${ACCOUNT_ID}:root" },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "AllowCloudWatchLogsDecryptLegacy",
      "Effect": "Allow",
      "Principal": { "Service": "logs.${REGION}.amazonaws.com" },
      "Action": ["kms:Decrypt"],
      "Resource": "*"
    }
  ]
}
EOF
  aws kms put-key-policy --key-id "$OLD_KEY_ARN" --policy-name default --policy file://old-policy.json --region "$REGION"
fi

echo "Done. KMS: $NEW_KEY_ARN associated to LogGroup: $LOG_GROUP"

ใช้:

chmod +x setup-cloudwatch-kms.sh
REGION=ap-southeast-2 ACCOUNT_ID=409661147964 LOG_GROUP=TPN-App-Logs ./setup-cloudwatch-kms.sh
