output "packer_vpc" {
  value = try(module.VPC[0].packer_vpc, null)
}
