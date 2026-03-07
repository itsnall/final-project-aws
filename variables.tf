variable "region" {
  description = "AWS Region Create"
  type        = string
  default     = "ap-southeast-1"
}

<<<<<<< HEAD
variable "db_password" {
  description = "Password for database RDS EduFlow"
  type        = string
  sensitive   = true
  
}

=======
>>>>>>> 575d412a6b4c0279344ae4fb9f33853820e76565
variable "admin_email" {
  description = "Email administrator untuk menerima notifikasi"
  type        = string
  default     = "andiisnal18@gmail.com"
}