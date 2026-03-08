variable "region" {
  description = "AWS Region Create"
  type        = string
  default     = "ap-southeast-1"
}

variable "acm_certificate_arn" {
  description = "ARN sertifikat ACM yang sudah ISSUED di region yang sama dengan ALB"
  type        = string
}

variable "admin_email" {
  description = "Email administrator untuk menerima notifikasi"
  type        = string
  default     = "andiisnal18@gmail.com"
}

variable "db_password" {
  description = "Password untuk database RDS EduFlow"
  type        = string
  sensitive   = true
}
