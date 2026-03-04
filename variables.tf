variable "region" {
  description = "AWS Region Create"
  type        = string
  default     = "ap-southeast-1" 
}

variable "db_password" {
  description = "Password for database RDS EduFlow"
  type        = string
  sensitive   = true
  default     = "EduflowAdmin123!" 
}

variable "admin_email" {
  description = "Email administrator untuk menerima notifikasi"
  type        = string
  default     = "andiisnal18@gmail.com" 
}