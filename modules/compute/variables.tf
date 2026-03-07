variable "vpc_id" { type = string }
variable "public_subnets" { type = list(string) }
variable "private_app_subnets" { type = list(string) }
variable "s3_bucket_arn" { type = string }
variable "acm_certificate_arn" { type = string }