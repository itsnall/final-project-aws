variable "bucket_name" {
  description = "Nama unik untuk S3 Bucket"
  type        = string
}

variable "vpc_id" {
   type = string 
}

variable "region" {
  type = string
}

variable "private_route_table_id" {
  type = string
}