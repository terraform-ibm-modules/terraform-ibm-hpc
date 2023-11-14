module "landing_zone" {
  source = "../../modules/landing_zone"
  # TODO: Add logic
  enable_landing_zone    = var.enable_bootstrap ? true : false
  allowed_cidr           = var.allowed_cidr
  compute_subnets_cidr   = var.compute_subnets_cidr
  cos_instance_name      = var.cos_instance_name
  enable_atracker        = var.enable_atracker
  enable_cos_integration = var.enable_cos_integration
  enable_vpc_flow_logs   = var.enable_vpc_flow_logs
  enable_vpn             = var.enable_vpn
  hpcs_instance_name     = var.hpcs_instance_name
  ibmcloud_api_key       = var.ibmcloud_api_key
  key_management         = var.key_management
  ssh_keys               = var.bastion_ssh_keys
  bastion_subnets_cidr   = var.bastion_subnets_cidr
  management_instances   = var.management_instances
  compute_instances      = var.static_compute_instances
  network_cidr           = var.network_cidr
  placement_strategy     = var.placement_strategy
  prefix                 = var.prefix
  protocol_instances     = var.protocol_instances
  protocol_subnets_cidr  = var.protocol_subnets_cidr
  resource_group         = var.resource_group
  storage_instances      = var.storage_instances
  storage_subnets_cidr   = var.storage_subnets_cidr
  vpc                    = var.vpc
  vpn_peer_address       = var.vpn_peer_address
  vpn_peer_cidr          = var.vpn_peer_cidr
  vpn_preshared_key      = var.vpn_preshared_key
  zones                  = var.zones
}

module "bastion" {
  source                     = "./../../modules/bastion"
  ibmcloud_api_key           = var.ibmcloud_api_key
  resource_group             = var.resource_group
  prefix                     = var.prefix
  zones                      = var.zones
  vpc_id                     = local.vpc_id
  network_cidr               = var.network_cidr
  enable_bastion             = var.enable_bastion
  bastion_subnets            = local.bastion_subnets
  enable_bootstrap           = var.enable_bootstrap
  ssh_keys                   = var.bastion_ssh_keys
  allowed_cidr               = var.allowed_cidr
  kms_encryption_enabled     = local.kms_encryption_enabled
  boot_volume_encryption_key = local.boot_volume_encryption_key
  existing_kms_instance_guid = local.existing_kms_instance_guid
}

module "bootstrap" {
  source                     = "./../../modules/bootstrap"
  ibmcloud_api_key           = var.ibmcloud_api_key
  resource_group             = var.resource_group
  prefix                     = var.prefix
  zones                      = var.zones
  vpc_id                     = local.vpc_id
  network_cidr               = var.network_cidr
  enable_bastion             = var.enable_bastion
  bastion_subnets            = local.bastion_subnets
  enable_bootstrap           = var.enable_bootstrap
  bootstrap_instance_profile = var.bootstrap_instance_profile
  ssh_keys                   = local.bastion_ssh_keys
  security_group_ids         = [local.bastion_security_group_id]
  bastion_public_key_content = local.bastion_public_key_content
  kms_encryption_enabled     = local.kms_encryption_enabled
  boot_volume_encryption_key = local.boot_volume_encryption_key
  existing_kms_instance_guid = local.existing_kms_instance_guid
  compute_ssh_keys           = var.compute_ssh_keys
  storage_ssh_keys           = var.storage_ssh_keys
  login_ssh_keys             = var.login_ssh_keys  
}

module "landing_zone_vsi" {
  source                     = "../../modules/landing_zone_vsi"
  ibmcloud_api_key           = var.ibmcloud_api_key
  resource_group             = var.resource_group
  prefix                     = var.prefix
  zones                      = var.zones
  vpc_id                     = local.vpc_id
  bastion_security_group_id  = local.bastion_security_group_id
  bastion_public_key_content = local.bastion_public_key_content
  login_subnets              = local.login_subnets
  login_ssh_keys             = var.login_ssh_keys
  login_image_name           = var.login_image_name
  login_instances            = local.login_instances
  compute_subnets            = local.compute_subnets
  compute_ssh_keys           = var.compute_ssh_keys
  management_image_name      = var.management_image_name
  management_instances       = local.management_instances
  static_compute_instances   = local.static_compute_instances
  dynamic_compute_instances  = var.dynamic_compute_instances
  compute_image_name         = var.compute_image_name
  storage_subnets            = local.storage_subnets
  storage_ssh_keys           = var.storage_ssh_keys
  storage_instances          = local.storage_instances
  storage_image_name         = var.storage_image_name
  protocol_subnets           = local.protocol_subnets
  protocol_instances         = local.protocol_instances
  nsd_details                = var.nsd_details
  dns_domain_names           = var.dns_domain_names
  kms_encryption_enabled     = local.kms_encryption_enabled
  boot_volume_encryption_key = local.boot_volume_encryption_key
}

module "file_storage" {
  source             = "../../modules/file_storage"
  ibmcloud_api_key   = var.ibmcloud_api_key
  zone               = var.zones[0] # always the first zone
  file_shares        = local.file_shares
  encryption_key_crn = local.boot_volume_encryption_key
  security_group_ids = local.compute_security_group_id
  subnet_id          = local.compute_subnet_id
}

module "dns" {
  source                 = "./../../modules/dns"
  ibmcloud_api_key       = var.ibmcloud_api_key
  prefix                 = var.prefix
  resource_group_id      = local.resource_group_id
  vpc_crn                = local.vpc_crn
  subnets_crn            = local.subnets_crn
  dns_instance_id        = var.dns_instance_id
  dns_custom_resolver_id = var.dns_custom_resolver_id
  dns_domain_names       = values(var.dns_domain_names)
}

module "compute_dns_records" {
  source           = "./../../modules/dns_record"
  ibmcloud_api_key = var.ibmcloud_api_key
  dns_instance_id  = local.dns_instance_id
  dns_zone_id      = local.compute_dns_zone_id
  dns_records      = local.compute_dns_records
}

module "storage_dns_records" {
  source           = "./../../modules/dns_record"
  ibmcloud_api_key = var.ibmcloud_api_key
  dns_instance_id  = local.dns_instance_id
  dns_zone_id      = local.storage_dns_zone_id
  dns_records      = local.storage_dns_records
}

module "protocol_dns_records" {
  source           = "./../../modules/dns_record"
  ibmcloud_api_key = var.ibmcloud_api_key
  dns_instance_id  = local.dns_instance_id
  dns_zone_id      = local.protocol_dns_zone_id
  dns_records      = local.protocol_dns_records
}

module "compute_inventory" {
  source         = "./../../modules/inventory"
  hosts          = local.compute_hosts
  inventory_path = local.compute_inventory_path
}

module "storage_inventory" {
  source         = "./../../modules/inventory"
  hosts          = local.storage_hosts
  inventory_path = local.storage_inventory_path
}

module "compute_playbook" {
  source           = "./../../modules/playbook"
  bastion_fip      = local.bastion_fip
  private_key_path = local.compute_private_key_path
  inventory_path   = local.compute_inventory_path
  playbook_path    = local.compute_playbook_path
  depends_on       = [module.compute_inventory]
}

module "storage_playbook" {
  source           = "./../../modules/playbook"
  bastion_fip      = local.bastion_fip
  private_key_path = local.storage_private_key_path
  inventory_path   = local.storage_inventory_path
  playbook_path    = local.storage_playbook_path
  depends_on       = [module.storage_inventory]
}
