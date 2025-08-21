terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  cw_service_principal = "logs.${var.region}.amazonaws.com"
  cw_log_group_arn     = "arn:aws:logs:${var.region}:${var.account_id}:log-group:${var.log_group_name}"
}

resource "aws_kms_key" "cw" {
  description             = var.kms_description
  enable_key_rotation     = true
  deletion_window_in_days = var.deletion_window_days
  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "key-default-1",
    Statement = [
      {
        Sid       = "EnableRoot",
        Effect    = "Allow",
        Principal = { AWS = "arn:aws:iam::${var.account_id}:root" },
        Action    = "kms:*",
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudWatchLogsUseKey",
        Effect    = "Allow",
        Principal = { Service = local.cw_service_principal },
        Action    = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ],
        Resource  = "*",
        Condition = {
          "ArnLike" = {
            "kms:EncryptionContext:aws:logs:arn" = local.cw_log_group_arn
          }
        }
      }
    ]
  })
  tags = var.tags
}

resource "aws_kms_alias" "cw" {
  name          = "alias/${var.kms_alias}"
  target_key_id = aws_kms_key.cw.key_id
}

# Associate KMS key to CloudWatch Logs group
resource "aws_cloudwatch_log_group" "this" {
  name              = var.log_group_name
  kms_key_id        = aws_kms_key.cw.arn
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# (Optional) add Decrypt permission to OLD key for reading legacy logs
data "aws_iam_policy_document" "old_key_policy_merged" {
  count = var.old_kms_key_arn == "" ? 0 : 1

  # fetch existing policy
  statement {
    sid     = "PlaceholderExistingPolicy"
    effect  = "Allow"
    actions = ["kms:DescribeKey"]
    principals { type = "AWS", identifiers = ["arn:aws:iam::${var.account_id}:root"] }
  }
}

# Use an external data source to fetch current policy (workaround without data source)
# -> In practice, pass old key policy via variable if strict IaC is desired.

# Grant decrypt to CloudWatch on OLD key
resource "aws_kms_key_policy" "old_key_decrypt" {
  count  = var.old_kms_key_arn == "" ? 0 : 1
  key_id = var.old_kms_key_arn

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "key-default-1",
    Statement = [
      {
        Sid       = "EnableRoot",
        Effect    = "Allow",
        Principal = { AWS = "arn:aws:iam::${var.account_id}:root" },
        Action    = "kms:*",
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudWatchLogsDecryptLegacy",
        Effect    = "Allow",
        Principal = { Service = local.cw_service_principal },
        Action    = ["kms:Decrypt"],
        Resource  = "*"
      }
    ]
