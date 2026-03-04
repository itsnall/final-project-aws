variable "vpc_cidr" {
  description = "CIDR block untuk VPC"
  type        = string
}

variable "public_cidrs" {
  description = "Daftar CIDR block untuk Public Subnet"
  type        = list(string)
}

variable "app_cidrs" {
  description = "Daftar CIDR block untuk Private App Subnet"
  type        = list(string)
}

variable "db_cidrs" {
  description = "Daftar CIDR block untuk Private DB Subnet"
  type        = list(string)
}

variable "azs" {
  description = "Daftar Availability Zones"
  type        = list(string)
}