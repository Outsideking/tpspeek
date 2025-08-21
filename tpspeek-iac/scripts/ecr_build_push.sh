#!/usr/bin/env bash
set -euo pipefail

REGION="${REGION:-ap-southeast-2}"
ACCOUNT_ID="${ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
REPO_NAME="tpspeek-backend"
IMAGE_TAG="${IMAGE_TAG:-latest}"

aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$REGION" >/dev/null 2>&1 || \
  aws ecr create-repository --repository-name "$REPO_NAME" --region "$REGION" >/dev/null

AWS_ECR="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${IMAGE_TAG}"

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# สั่ง build จากโฟลเดอร์ที่มี Dockerfile ของ TPSpeek API (FastAPI/Node ตามที่คุณทำ)
docker build -t "$REPO_NAME:$IMAGE_TAG" .
docker tag "$REPO_NAME:$IMAGE_TAG" "$AWS_ECR"
docker push "$AWS_ECR"

echo "✅ Pushed: $AWS_ECR"
echo "➡️  ตั้งค่า Terraform var: -var=\"image_tag=${IMAGE_TAG}\""
