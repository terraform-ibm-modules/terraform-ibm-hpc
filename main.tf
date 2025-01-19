module "landing_zone" {
  source                        = "./modules/landing_zone"
  allowed_cidr                  = var.allowed_cidr
  compute_subnets_cidr          = var.compute_subnets_cidr
  clusters                      = var.clusters
  cos_instance_name             = var.cos_instance_name
  enable_atracker               = var.observability_atracker_enable && (var.observability_atracker_target_type == "cos") ? true : false
  enable_cos_integration        = var.enable_cos_integration
  enable_vpc_flow_logs          = var.enable_vpc_flow_logs
  enable_vpn                    = var.enable_vpn
  hpcs_instance_name            = var.hpcs_instance_name
  key_management                = var.key_management
  kms_instance_name             = var.kms_instance_name
  kms_key_name                  = var.kms_key_name
  ssh_keys                      = local.bastion_ssh_keys
  bastion_subnets_cidr          = var.bastion_subnets_cidr
  management_instances          = var.management_instances
  compute_instances             = var.static_compute_instances
  network_cidr                  = var.network_cidr
  placement_strategy            = var.placement_strategy
  prefix                        = var.prefix
  protocol_instances            = var.protocol_instances
  protocol_subnets_cidr         = var.protocol_subnets_cidr
  resource_group                = var.resource_group
  storage_instances             = var.storage_instances
  storage_subnets_cidr          = var.storage_subnets_cidr
  vpc                           = var.vpc
  vpn_peer_address              = var.vpn_peer_address
  vpn_peer_cidr                 = var.vpn_peer_cidr
  vpn_preshared_key             = var.vpn_preshared_key
  zones                         = var.zones
  scc_enable                    = var.scc_enable
  skip_flowlogs_s2s_auth_policy = var.skip_flowlogs_s2s_auth_policy
  skip_kms_s2s_auth_policy      = var.skip_kms_s2s_auth_policy
  observability_logs_enable     = var.observability_logs_enable_for_management || var.observability_logs_enable_for_compute || (var.observability_atracker_enable && var.observability_atracker_target_type == "cloudlogs") ? true : false
}

module "deployer" {
  source                        = "./modules/deployer"
  resource_group                = var.resource_group
  prefix                        = var.prefix
  zones                         = var.zones
  vpc_id                        = local.vpc_id
  network_cidr                  = var.network_cidr
  enable_bastion                = var.enable_bastion
  bastion_subnets               = local.bastion_subnets
  bastion_image                 = var.bastion_image
  bastion_instance_profile      = var.bastion_instance_profile
  enable_deployer               = var.enable_deployer
  deployer_image                = var.deployer_image
  deployer_instance_profile     = var.deployer_instance_profile
  ssh_keys                      = local.bastion_ssh_keys
  allowed_cidr                  = var.allowed_cidr
  kms_encryption_enabled        = local.kms_encryption_enabled
  boot_volume_encryption_key    = local.boot_volume_encryption_key
  existing_kms_instance_guid    = local.existing_kms_instance_guid
  skip_iam_authorization_policy = var.skip_iam_authorization_policy
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

###################################################
# Observability Modules
###################################################

module "cloud_monitoring_instance_creation" {
  source                         = "./modules/observability_instance"
  location                       = local.region
  rg                             = local.resource_group_id
  cloud_monitoring_provision     = var.observability_monitoring_enable
  observability_monitoring_plan  = var.observability_monitoring_plan
  enable_metrics_routing         = var.observability_enable_metrics_routing
  enable_platform_logs           = var.observability_enable_platform_logs
  cluster_prefix                 = var.prefix
  cloud_monitoring_instance_name = "${var.prefix}-metrics"
  cloud_logs_provision           = var.observability_logs_enable_for_management || var.observability_logs_enable_for_compute ? true : false
  cloud_logs_instance_name       = "${var.prefix}-cloud-logs"
  cloud_logs_retention_period    = var.observability_logs_retention_period
  cloud_logs_as_atracker_target  = var.observability_atracker_enable && (var.observability_atracker_target_type == "cloudlogs") ? true : false
  cloud_logs_data_bucket         = length([for bucket in local.cos_data : bucket if strcontains(bucket.bucket_name, "logs-data-bucket")]) > 0 ? [for bucket in local.cos_data : bucket if strcontains(bucket.bucket_name, "logs-data-bucket")][0] : null
  cloud_metrics_data_bucket      = length([for bucket in local.cos_data : bucket if strcontains(bucket.bucket_name, "metrics-data-bucket")]) > 0 ? [for bucket in local.cos_data : bucket if strcontains(bucket.bucket_name, "metrics-data-bucket")][0] : null
  tags                           = ["hpc", var.prefix]
}

# Code for SCC Instance
module "scc_instance_and_profile" {
  count                   = var.scc_enable ? 1 : 0
  source                  = "./modules/security/scc"
  location                = var.scc_location != "" ? var.scc_location : "us-south"
  rg                      = local.resource_group_id
  scc_profile             = var.scc_enable ? var.scc_profile : ""
  # scc_profile_version     = var.scc_profile != "" && var.scc_profile != null ? var.scc_profile_version : ""
  event_notification_plan = var.scc_event_notification_plan
  tags                    = ["hpc", var.prefix]
  prefix                  = var.prefix
  cos_bucket              = [for name in module.landing_zone.cos_buckets_names : name if strcontains(name, "scc-bucket")][0]
  cos_instance_crn        = module.landing_zone.cos_instance_crns[0]
}
