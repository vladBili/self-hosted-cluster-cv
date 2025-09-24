variable "ami_name" {
  type    = string
  default = " "
}

variable "asg_dict" {
  type = map(map(any))
}
