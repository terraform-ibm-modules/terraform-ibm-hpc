locals {
  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))
}

module "hpc_basic_example" {
  source             = "../.."
  ibmcloud_api_key   = var.ibmcloud_api_key
  resource_group     = var.resource_group
  cluster_prefix     = var.cluster_prefix
  zones              = var.zones
  bastion_ssh_keys   = var.bastion_ssh_keys
  compute_ssh_keys   = var.compute_ssh_keys
  remote_allowed_ips = var.remote_allowed_ips
  cluster_id         = var.cluster_id
  contract_id        = var.contract_id
}
