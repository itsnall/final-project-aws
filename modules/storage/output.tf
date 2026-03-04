output "bucket_name" {
  value = aws_s3_bucket.eduflow_assets.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.eduflow_assets.arn
}