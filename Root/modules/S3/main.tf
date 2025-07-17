# Generate random suffix for each s3 bucket in buckets
resource "random_string" "s3_bucket_random_suffix" {
  for_each = var.buckets
  length   = each.value.bucket_suffix_length
  special  = false
  upper    = false
  lifecycle {
    ignore_changes = [result]
  }
}

# Create s3 bucket
resource "aws_s3_bucket" "s3_buckets" {
  for_each = var.buckets
  bucket   = "${each.value.bucket_prefix}-${random_string.s3_bucket_random_suffix[each.key].result}"
  tags = merge(
    {
      Name = each.value.bucket_prefix
    },
    each.value.enable_versioning ? { "versioning" = "true" } : { "versioning" = "false" }
  )
}

resource "aws_s3_bucket_versioning" "s3_bucket_versioning" {
  for_each = {
    for bucket, bucket_options in var.buckets : bucket => bucket_options if bucket_options.enable_versioning
  }
  bucket = aws_s3_bucket.s3_buckets[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

# Create terraform partial backends for each department
resource "local_file" "tf_partial_backend_config_files" {
  for_each = var.buckets["terraform_state"].department
  content = templatefile("${path.root}/templates/backend.tftpl",
    { bucket = aws_s3_bucket.s3_buckets["terraform_state"].bucket,
      key    = "backend/${each.key}/state",
      region = var.buckets["terraform_state"].region
    }
  )
  filename = abspath("${path.root}/../IAM/terraform/env/${each.key}/config/conf.hcl")
}
