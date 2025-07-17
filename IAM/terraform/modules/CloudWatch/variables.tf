variable "function" {
  type = map(object({
    arn  = string,
    name = string,
    rate = string
  }))
}

variable "enabled" {
  type = bool
}
