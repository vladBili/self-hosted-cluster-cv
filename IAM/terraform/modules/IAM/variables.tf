variable "enabled" {
  type = bool
}

variable "oidc" {
  type = map(map(any))
}
