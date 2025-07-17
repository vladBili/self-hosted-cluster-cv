# Global variables
variable "target" {
  type    = string
  default = "project"
}

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

# IAM module
variable "iam_user_department_map" {
  type    = map(string)
  default = { "testing" : "testing", "development" : "development" }
  validation {
    condition     = alltrue([for value in toset(values(var.iam_user_department_map)) : contains(["development", "testing"], value)])
    error_message = "Allowed values for departments are only 'development' or 'testing"
  }
}

# S3 module
variable "tf_state_bucket_prefix" {
  type    = string
  default = "s3-bucket-state"
}

variable "tf_state_bucket_suffix_length" {
  type    = number
  default = 8
}

variable "tf_state_bucket_versioning" {
  type    = bool
  default = true
}
