module "hpcaas" {
  source                    = "./../.."
  scheduler                 = "HPCaaS"
  ibm_customer_number       = var.ibm_customer_number
  zones                     = var.zones
  allowed_cidr              = var.allowed_cidr
  prefix                    = local.env.prefix
  ssh_keys                  = local.env.ssh_keys
  existing_resource_group   = local.env.existing_resource_group
  deployer_instance_profile = local.env.deployer_instance_profile
  bastion_ssh_keys          = local.env.bastion_ssh_keys
  bastion_subnets_cidr      = [local.env.bastion_subnets_cidr]
  compute_ssh_keys          = local.env.compute_ssh_keys
  compute_subnets_cidr      = [local.env.compute_subnets_cidr]
  cos_instance_name         = local.env.cos_instance_name
  dns_custom_resolver_id    = local.env.dns_custom_resolver_id
  dns_instance_id           = local.env.dns_instance_id
  dns_domain_names          = local.env.dns_domain_names
  dynamic_compute_instances = local.env.dynamic_compute_instances
  enable_atracker           = local.env.enable_atracker
  enable_bastion            = local.env.enable_bastion
  enable_deployer           = local.env.enable_deployer
  enable_cos_integration    = local.env.enable_cos_integration
  enable_vpc_flow_logs      = local.env.enable_vpc_flow_logs
  enable_vpn                = local.env.enable_vpn
  file_shares               = local.env.file_shares
  key_management            = local.env.key_management
  client_instances          = local.env.client_instances
  client_ssh_keys           = local.env.client_ssh_keys
  management_instances      = local.env.management_instances
  network_cidr              = local.env.network_cidr
  placement_strategy        = local.env.placement_strategy
  protocol_instances        = local.env.protocol_instances
  protocol_subnets_cidr     = [local.env.protocol_subnets_cidr]
  static_compute_instances  = local.env.static_compute_instances
  storage_instances         = local.env.storage_instances
  storage_ssh_keys          = local.env.storage_ssh_keys
  storage_subnets_cidr      = [local.env.storage_subnets_cidr]
  vpc_name                  = local.env.vpc_name
  vpn_peer_address          = local.env.vpn_peer_address
  vpn_peer_cidr             = local.env.vpn_peer_cidr
  vpn_preshared_key         = local.env.vpn_preshared_key

  # compute_gui_password = local.env.compute_gui_password
  # compute_gui_username = local.env.compute_gui_username
  # hpcs_instance_name   = local.env.hpcs_instance_name
  # client_subnets_cidr  = [local.env.client_subnets_cidr]
  # storage_gui_password = local.env.storage_gui_password
  # storage_gui_username = local.env.storage_gui_username
}
