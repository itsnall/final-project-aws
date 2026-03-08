output "db_endpoint" {
  description = "Alamat endpoint koneksi ke RDS MySQL"
  value       = aws_db_instance.main.endpoint
}

output "db_password" {
  description = "The password for the RDS instance"
  value       = local.db_creds.password
  sensitive   = true 
}