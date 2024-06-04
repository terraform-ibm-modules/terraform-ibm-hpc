module "create_vpc" {
  source               = "../../modules/landing_zone_vpc"
  allowed_cidr         = var.remote_allowed_ips
  ibmcloud_api_key     = var.ibmcloud_api_key
  ssh_keys             = var.bastion_ssh_keys
  prefix               = var.cluster_prefix
  resource_group       = var.resource_group
  zones                = var.zones
  network_cidr         = var.vpc_cidr
  bastion_subnets_cidr = var.vpc_cluster_login_private_subnets_cidr_blocks
  compute_subnets_cidr = var.vpc_cluster_private_subnets_cidr_blocks
  enable_hub           = var.enable_hub
}
