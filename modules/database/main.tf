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
  identifier             = "eduflow-db"
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro" 
  db_name                = "eduflowdb"
  username               = "admin"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false 
  skip_final_snapshot    = true  
}