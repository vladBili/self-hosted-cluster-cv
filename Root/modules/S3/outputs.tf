output "s3_state_bucket_arn" {
  value = aws_s3_bucket.s3_buckets["terraform_state"].arn
}
