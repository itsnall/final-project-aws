# 1. Membuat S3 Bucket
resource "aws_s3_bucket" "eduflow_assets" {
  bucket = var.bucket_name
  tags = {
    Name = "eduflow-course-materials"
  }
}

# 2. Mengaktifkan Versioning
resource "aws_s3_bucket_versioning" "eduflow_versioning" {
  bucket = aws_s3_bucket.eduflow_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 3. Mengaktifkan Enkripsi (Default AWS KMS)
resource "aws_s3_bucket_server_side_encryption_configuration" "eduflow_encryption" {
  bucket = aws_s3_bucket.eduflow_assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 4. Memblokir Semua Akses Publik (Keamanan Ketat)
resource "aws_s3_bucket_public_access_block" "eduflow_public_block" {
  bucket = aws_s3_bucket.eduflow_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

## Membuat VPC Gateway agar Backend EC2 tidak perlu melewati NAT untuk akses S3 (Cost Optimization)
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id = var.vpc_id
  service_name = "com.amazonaws.${var.region}.s3"

  route_table_ids = [var.private_route_table_id]
  tags = {
    Name = "eduflow-s3-endpoint"
  }
}