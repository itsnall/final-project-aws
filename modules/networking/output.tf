output "vpc_id" {
  description = "ID dari VPC utama"
  value       = aws_vpc.main.id
}

output "db_subnet_ids" {
  description = "Daftar ID dari Private Subnet untuk Database"
  value       = aws_subnet.private_db[*].id
}

output "public_subnets" {
  description = "Daftar ID dari Public Subnet"
  value       = aws_subnet.public[*].id
}

output "private_app_subnets" {
  description = "Daftar ID dari Private App Subnet"
  value       = aws_subnet.private_app[*].id
}

output "private_route_table_id" {
  description = "ID dari Private Route Table"
  value = aws_route_table.private.id
}