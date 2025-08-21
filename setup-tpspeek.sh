#!/bin/bash
set -euo pipefail

REGION="ap-southeast-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Creating S3 bucket..."
aws s3 mb s3://tpspeek-data-$ACCOUNT_ID --region $REGION || true

echo "Creating DynamoDB table..."
aws dynamodb create-table \
  --table-name TPSpeekConfig \
  --attribute-definitions AttributeName=ConfigID,AttributeType=S \
  --key-schema AttributeName=ConfigID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION || true

echo "Creating LogGroup..."
aws logs create-log-group --log-group-name TPSpeek-App-Logs --region $REGION || true

echo "Attaching IAM Role..."
aws iam create-role \
  --role-name TPSpeekEcsTaskRole \
  --assume-role-policy-document file://ecs-assume.json || true
