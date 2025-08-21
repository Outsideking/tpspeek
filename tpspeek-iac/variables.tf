variable "region"       { type = string  default = "ap-southeast-2" }
variable "account_id"   { type = string }
variable "image_tag"    { type = string  default = "latest" } # tag ที่คุณ push ขึ้น ECR
variable "task_cpu"     { type = number  default = 512 }
variable "task_memory"  { type = number  default = 1024 }
variable "desired_count"{ type = number  default = 1 }
# variable "acm_certificate_arn" { type = string default = "" } # ใช้เมื่อเปิด HTTPS listener
