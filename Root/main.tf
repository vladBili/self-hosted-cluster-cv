provider "aws" {
  region  = var.aws_region
  profile = "root"
  default_tags {
    tags = {
      target = var.target
    }
  }
}

data "aws_caller_identity" "current_account" {}

locals {
  departments = toset(values(var.iam_user_department_map))
  users       = toset(keys(var.iam_user_department_map))
  account_id  = data.aws_caller_identity.current_account.account_id
}

module "S3" {
  source = "./modules/S3"
  buckets = {
    "terraform_state" : {
      bucket_prefix        = var.tf_state_bucket_prefix,
      bucket_suffix_length = var.tf_state_bucket_suffix_length,
      enable_versioning    = var.tf_state_bucket_versioning,
      region               = var.aws_region,
      department           = local.departments
    },
    "example" : {
      bucket_prefix        = var.tf_state_bucket_prefix,
      bucket_suffix_length = var.tf_state_bucket_suffix_length,
      enable_versioning    = false,
      region               = var.aws_region,
      department           = local.departments
    }
  }
}

module "IAM" {
  source              = "./modules/IAM"
  departments         = local.departments
  users               = local.users
  user_department_map = var.iam_user_department_map
  region              = var.aws_region
  account_id          = local.account_id
  target              = var.target
  resource_arns = {
    "S3" : {
      "state_bucket" = module.S3.s3_state_bucket_arn
    }
  }
}






