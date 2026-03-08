output "db_endpoint" {
  description = "Alamat endpoint koneksi ke RDS MySQL"
  value       = aws_db_instance.main.endpoint
}