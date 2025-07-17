terraform {
  backend "s3" {
    bucket = ""
    key    = ""
    region = ""
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.91.0"
    }
  }
}