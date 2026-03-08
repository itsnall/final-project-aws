variable "region" {
  description = "AWS Region Create"
  type        = string
  default     = "ap-southeast-1"
}

variable "acm_certificate_arn" {
  description = "ARN sertifikat ACM yang sudah ISSUED di region yang sama dengan ALB"
  type        = string
  default     = "arn:aws:acm:ap-southeast-1:123456789012:certificate/dummy-cert"
}

variable "admin_email" {
  description = "Email administrator untuk menerima notifikasi"
  type        = string
  default     = "andiisnal18@gmail.com"
}