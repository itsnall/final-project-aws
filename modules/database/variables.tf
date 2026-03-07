variable "vpc_id" { type = string }
variable "db_subnet_ids" { type = list(string) }
variable "db_password" {
  description = "Password untuk database RDS"
  type        = string
  sensitive   = true
}