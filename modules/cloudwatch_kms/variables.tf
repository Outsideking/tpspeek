variable "region" {
  type        = string
  description = "AWS region, e.g. ap-southeast-2"
}

variable "account_id" {
  type        = string
  description = "AWS Account ID"
}

variable "log_group_name" {
  type        = string
  description = "CloudWatch Log Group name"
}

variable "kms_alias" {
  type        = string
  description = "Alias name for the new KMS key"
  default     = "cw-logs"
}

variable "kms_description" {
  type        = string
  default     = "KMS key for CloudWatch Logs encryption"
}

variable "deletion_window_days" {
  type        = number
  default     = 30
}

variable "log_retention_days" {
  type        = number
  default     = 30
}

variable "old_kms_key_arn" {
  type        = string
  description = "(Optional) Existing OLD KMS key ARN to grant Decrypt for legacy logs"
  default     = ""
}

variable "tags" {
  type        = map(string)
  default     = {}
}

modules/cloudwatch_kms/outputs.tf

output "kms_key_arn" {
  value = aws_kms_key.cw.arn
}

output "kms_key_id" {
  value = aws_kms_key.cw.key_id
}

output "kms_alias_arn" {
  value = aws_kms_alias.cw.arn
