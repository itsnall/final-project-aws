# 1. Look up the secret metadata
data "aws_secretsmanager_secret" "db_secret" {
  name = "eduflow/db/credentials"
}

# 2. Retrieve the actual secret version (the JSON string)
data "aws_secretsmanager_secret_version" "current" {
  secret_id = data.aws_secretsmanager_secret.db_secret.id
}

# 3. Decode the JSON string into a local map
locals {
  db_creds = jsondecode(
    data.aws_secretsmanager_secret_version.current.secret_string
  )
}
# 1. Security Group untuk RDS (Hanya mengizinkan trafik dari dalam VPC)
resource "aws_security_group" "rds_sg" {
  name   = "eduflow-rds-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
}

# 2. DB Subnet Group (Memberitahu RDS di subnet mana ia boleh hidup)
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "eduflow-db-subnet-group"
  subnet_ids = var.db_subnet_ids
}

# 3. Instance RDS (MySQL)
resource "aws_db_instance" "main" {
  identifier              = "eduflow-db"
  allocated_storage       = 20
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  db_name                 = "eduflowdb"
  username                = local.db_creds.user
  password                = local.db_creds.password
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  multi_az                = true
  backup_retention_period = 7 # Simpan backup selama 7 hari
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  publicly_accessible     = false
  skip_final_snapshot     = true
}