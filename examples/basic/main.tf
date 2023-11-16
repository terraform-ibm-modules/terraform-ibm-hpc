locals {
  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))
}

module "hpc_basic_example" {
  source           = "../.."
  ibmcloud_api_key = var.ibmcloud_api_key
  prefix           = var.prefix
  zones            = var.zones
  resource_group   = var.resource_group
  bastion_ssh_keys = var.ssh_keys
  login_ssh_keys   = var.ssh_keys
  compute_ssh_keys = var.ssh_keys
  storage_ssh_keys = var.ssh_keys
}
