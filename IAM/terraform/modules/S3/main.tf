# Create s3 bucket
resource "aws_s3_bucket" "airlow_log_buckets" {
  count  = var.enabled ? 1 : 0
  bucket = "s3-bucket-${terraform.workspace}-vlad-bilii"
  tags = {
    department = terraform.workspace
  }
}
