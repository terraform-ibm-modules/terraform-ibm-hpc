module "landing_zone" {
  source                 = "./modules/landing_zone"
  allowed_cidr           = var.allowed_cidr
  compute_subnets_cidr   = var.compute_subnets_cidr
  clusters               = var.clusters
  cos_instance_name      = var.cos_instance_name
  enable_atracker        = var.enable_atracker
  enable_cos_integration = var.enable_cos_integration
  enable_vpc_flow_logs   = var.enable_vpc_flow_logs
  enable_vpn             = var.enable_vpn
  hpcs_instance_name     = var.hpcs_instance_name
  key_management         = var.key_management
  ssh_keys               = local.bastion_ssh_keys
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

module "deployer" {
  source                     = "./modules/deployer"
  resource_group             = var.resource_group
  prefix                     = var.prefix
  zones                      = var.zones
  vpc_id                     = local.vpc_id
  network_cidr               = var.network_cidr
  enable_bastion             = var.enable_bastion
  bastion_subnets            = local.bastion_subnets
  bastion_image              = var.bastion_image
  bastion_instance_profile   = var.bastion_instance_profile
  enable_deployer            = var.enable_deployer
  deployer_image             = var.deployer_image
  deployer_instance_profile  = var.deployer_instance_profile
  ssh_keys                   = local.bastion_ssh_keys
  allowed_cidr               = var.allowed_cidr
  kms_encryption_enabled     = local.kms_encryption_enabled
  boot_volume_encryption_key = local.boot_volume_encryption_key
  existing_kms_instance_guid = local.existing_kms_instance_guid
}

module "landing_zone_vsi" {
  source                     = "./modules/landing_zone_vsi"
  resource_group             = var.resource_group
  prefix                     = var.prefix
  zones                      = var.zones
  vpc_id                     = local.vpc_id
  bastion_security_group_id  = local.bastion_security_group_id
  bastion_public_key_content = local.bastion_public_key_content
  client_subnets             = local.client_subnets
  client_ssh_keys            = local.client_ssh_keys
  client_instances           = var.client_instances
  compute_subnets            = local.compute_subnets
  compute_ssh_keys           = local.compute_ssh_keys
  management_instances       = var.management_instances
  static_compute_instances   = var.static_compute_instances
  dynamic_compute_instances  = var.dynamic_compute_instances
  storage_subnets            = local.storage_subnets
  storage_ssh_keys           = local.storage_ssh_keys
  storage_instances          = var.storage_instances
  protocol_subnets           = local.protocol_subnets
  protocol_instances         = var.protocol_instances
  nsd_details                = var.nsd_details
  dns_domain_names           = var.dns_domain_names
  kms_encryption_enabled     = local.kms_encryption_enabled
  boot_volume_encryption_key = local.boot_volume_encryption_key
}

module "file_storage" {
  source             = "./modules/file_storage"
  zone               = var.zones[0] # always the first zone
  resource_group_id  = local.resource_group_id
  file_shares        = local.file_shares
  encryption_key_crn = local.boot_volume_encryption_key
  security_group_ids = local.compute_security_group_id
  subnet_id          = local.compute_subnet_id
}

module "dns" {
  source                 = "./modules/dns"
  prefix                 = var.prefix
  resource_group_id      = local.resource_group_id
  vpc_crn                = local.vpc_crn
  subnets_crn            = local.subnets_crn
  dns_instance_id        = var.dns_instance_id
  dns_custom_resolver_id = var.dns_custom_resolver_id
  dns_domain_names       = values(var.dns_domain_names)
}

module "compute_dns_records" {
  source          = "./modules/dns_record"
  dns_instance_id = local.dns_instance_id
  dns_zone_id     = local.compute_dns_zone_id
  dns_records     = local.compute_dns_records
}

module "storage_dns_records" {
  source          = "./modules/dns_record"
  dns_instance_id = local.dns_instance_id
  dns_zone_id     = local.storage_dns_zone_id
  dns_records     = local.storage_dns_records
}

module "protocol_dns_records" {
  source          = "./modules/dns_record"
  dns_instance_id = local.dns_instance_id
  dns_zone_id     = local.protocol_dns_zone_id
  dns_records     = local.protocol_dns_records
}

resource "time_sleep" "wait_60_seconds" {
  create_duration = "60s"
  depends_on          = [ module.storage_dns_records, module.protocol_dns_records, module.compute_dns_records ]
}


module "compute_inventory" {
  source              = "./modules/inventory"
  hosts               = local.compute_hosts
  inventory_path      = local.compute_inventory_path
  name_mount_path_map = local.fileshare_name_mount_path_map
  depends_on          = [ time_sleep.wait_60_seconds ]
}

module "storage_inventory" {
  source              = "./modules/inventory"
  hosts               = local.storage_hosts
  inventory_path      = local.storage_inventory_path
  name_mount_path_map = local.fileshare_name_mount_path_map
  depends_on          = [ time_sleep.wait_60_seconds ]
}

module "compute_playbook" {
  source           = "./modules/playbook"
  bastion_fip      = local.bastion_fip
  private_key_path = local.compute_private_key_path
  inventory_path   = local.compute_inventory_path
  playbook_path    = local.compute_playbook_path
  depends_on       = [ module.compute_inventory ]
}

module "storage_playbook" {
  source           = "./modules/playbook"
  bastion_fip      = local.bastion_fip
  private_key_path = local.storage_private_key_path
  inventory_path   = local.storage_inventory_path
  playbook_path    = local.storage_playbook_path
  depends_on       = [ module.storage_inventory ]
}

