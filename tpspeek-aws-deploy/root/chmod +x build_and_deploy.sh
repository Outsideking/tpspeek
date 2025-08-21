#!/usr/bin/env bash
set -euo pipefail

STACK_NAME="${STACK_NAME:-tpspeek-stack}"
REGION="${REGION:-ap-southeast-2}"
OUTPUT_BUCKET="${OUTPUT_BUCKET:-tpspeek-outputs-$(date +%s)}"
LAMBDA_ZIP="tpspeek_lambda.zip"
S3_UPLOAD_BUCKET="${S3_UPLOAD_BUCKET:-${OUTPUT_BUCKET}}"

echo "1) Create output S3 bucket (for results & lambda package)..."
aws s3api create-bucket --bucket "${S3_UPLOAD_BUCKET}" --region "${REGION}" --create-bucket-configuration LocationConstraint=${REGION} 2>/dev/null || true

echo "2) Zip Lambda code..."
cd lambda
zip -r ../${LAMBDA_ZIP} .
cd ..

echo "3) Upload lambda zip to S3 (for manual update later)..."
aws s3 cp ${LAMBDA_ZIP} s3://${S3_UPLOAD_BUCKET}/${LAMBDA_ZIP} --region ${REGION}

echo "4) Deploy CloudFormation stack (creates Lambda role, API GW, bucket, kms, logs)..."
aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name ${STACK_NAME} \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides OutputBucketName=${OUTPUT_BUCKET} Region=${REGION} StackPrefix=tpspeek \
  --region ${REGION}

echo "5) Update Lambda code with uploaded zip..."
# find the lambda function name from stack outputs
LAMBDA_NAME=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${REGION} --query "Stacks[0].Outputs[?OutputKey=='LambdaName'].OutputValue" --output text)
if [ -z "$LAMBDA_NAME" ] || [ "$LAMBDA_NAME" = "None" ]; then
  echo "Could not fetch Lambda name from stack outputs; aborting update"
  exit 1
fi
aws lambda update-function-code --function-name "${LAMBDA_NAME}" --s3-bucket "${S3_UPLOAD_BUCKET}" --s3-key "${LAMBDA_ZIP}" --region ${REGION}
echo "✅ Lambda code updated."

# print API endpoint
API_ID=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${REGION} --query "Stacks[0].Outputs[?OutputKey=='ApiEndpoint'].OutputValue" --output text)
echo "API endpoint (invoke): https://${API_ID}"
echo "Output bucket: ${OUTPUT_BUCKET}"
echo "Done."
