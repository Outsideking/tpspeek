#!/usr/bin/env bash
set -euo pipefail

REGION="ap-southeast-2"
STACK_NAME="TPspeekStackV2"
LAMBDA_NAME="TPspeekTranslateV2"
OUTPUT_BUCKET="tpspeek-outputs-$(date +%s)"
LAMBDA_ZIP="tpspeek_lambda.zip"

echo "1) สร้าง S3 bucket สำหรับเก็บ Lambda zip"
aws s3api create-bucket --bucket ${OUTPUT_BUCKET} --region ${REGION} --create-bucket-configuration LocationConstraint=${REGION} 2>/dev/null || true

echo "2) zip โค้ด Lambda"
cd lambda
zip -r ../${LAMBDA_ZIP} .
cd ..

echo "3) upload zip ไป S3"
aws s3 cp ${LAMBDA_ZIP} s3://${OUTPUT_BUCKET}/${LAMBDA_ZIP} --region ${REGION}

echo "4) สร้าง Lambda Function"
aws lambda create-function \
  --function-name ${LAMBDA_NAME} \
  --runtime python3.11 \
  --role arn:aws:iam::<YOUR_ACCOUNT_ID>:role/<LAMBDA_ROLE> \
  --handler handler.lambda_handler \
  --code S3Bucket=${OUTPUT_BUCKET},S3Key=${LAMBDA_ZIP} \
  --timeout 300 \
  --memory-size 1536 \
  --region ${REGION} || echo "Lambda already exists, updating code..." \
  && aws lambda update-function-code \
       --function-name ${LAMBDA_NAME} \
       --s3-bucket ${OUTPUT_BUCKET} \
       --s3-key ${LAMBDA_ZIP} \
       --region ${REGION}

echo "5) สร้าง HTTP API Gateway"
API_ID=$(aws apigatewayv2 create-api \
    --name "TPspeekAPIv2" \
    --protocol-type HTTP \
    --target arn:aws:lambda:${REGION}:$(aws sts get-caller-identity --query Account --output text):function:${LAMBDA_NAME} \
    --query "ApiId" --output text)

echo "6) สร้าง default route"
aws apigatewayv2 create-route --api-id ${API_ID} --route-key "$default" --target "integrations/$(aws apigatewayv2 create-integration --api-id ${API_ID} --integration-type AWS_PROXY --integration-uri arn:aws:lambda:${REGION}:$(aws sts get-caller-identity --query Account --output text):function:${LAMBDA_NAME} --query "IntegrationId" --output text)"

echo "7) Deploy API"
aws apigatewayv2 create-deployment --api-id ${API_ID}

echo "8) ให้ Lambda ถูกเรียกโดย API Gateway"
aws lambda add-permission \
  --function-name ${LAMBDA_NAME} \
  --statement-id "APIGatewayInvoke" \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${REGION}:$(aws sts get-caller-identity --query Account --output text):${API_ID}/*/*"

echo "✅ Deploy เสร็จ"
echo "API Endpoint: https://${API_ID}.execute-api.${REGION}.amazonaws.com/"
