variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "account_id" {
  type = string
}

variable "target" {
  type    = string
  default = "project"
}

variable "resource_arns" {
  type = map(map(string))
}

variable "departments" {
  type = set(string)
}

variable "users" {
  type = set(string)
}

variable "user_department_map" {
  type = map(string)
}
