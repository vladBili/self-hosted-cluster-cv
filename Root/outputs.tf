output "packer_vpc" {
  value = try(module.VPC.packer_vpc, null)
}
