module "landing_zone" {
  source                        = "./modules/landing_zone"
  enable_landing_zone           = var.enable_landing_zone
  allowed_cidr                  = var.allowed_cidr
  compute_subnets_cidr          = var.compute_subnets_cidr
  cos_instance_name             = var.cos_instance_name
  enable_atracker               = var.observability_atracker_enable && (var.observability_atracker_target_type == "cos") ? true : false
  enable_cos_integration        = var.enable_cos_integration
  enable_vpc_flow_logs          = var.enable_vpc_flow_logs
  enable_vpn                    = var.enable_vpn
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
  existing_resource_group       = var.existing_resource_group
  storage_instances             = var.storage_instances
  storage_subnets_cidr          = var.storage_subnets_cidr
  vpc_name                      = var.vpc_name
  vpn_peer_address              = var.vpn_peer_address
  vpn_peer_cidr                 = var.vpn_peer_cidr
  vpn_preshared_key             = var.vpn_preshared_key
  zones                         = var.zones
  scc_enable                    = var.scc_enable
  skip_flowlogs_s2s_auth_policy = var.skip_flowlogs_s2s_auth_policy
  skip_kms_s2s_auth_policy      = var.skip_kms_s2s_auth_policy
  observability_logs_enable     = var.observability_logs_enable_for_management || var.observability_logs_enable_for_compute || (var.observability_atracker_enable && var.observability_atracker_target_type == "cloudlogs") ? true : false
  # hpcs_instance_name            = var.hpcs_instance_name
  # clusters                      = var.clusters
}

module "deployer" {
  source                        = "./modules/deployer"
  scheduler                     = var.scheduler
  existing_resource_group       = var.existing_resource_group
  prefix                        = var.prefix
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
  dns_domain_names              = var.dns_domain_names
}

module "landing_zone_vsi" {
  count                      = var.enable_deployer == false ? 1 : 0
  source                     = "./modules/landing_zone_vsi"
  existing_resource_group    = var.existing_resource_group
  prefix                     = var.prefix
  vpc_id                     = local.vpc_id
  bastion_security_group_id  = var.bastion_security_group_id
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
  enable_bastion             = var.enable_bastion
}

module "prepare_tf_input" {
  source                    = "./modules/prepare_tf_input"
  enable_deployer           = var.enable_deployer
  deployer_ip               = local.deployer_ip
  ibmcloud_api_key          = var.ibmcloud_api_key
  existing_resource_group   = var.existing_resource_group
  prefix                    = var.prefix
  zones                     = var.zones
  compute_ssh_keys          = local.compute_ssh_keys
  storage_ssh_keys          = local.storage_ssh_keys
  storage_instances         = var.storage_instances
  management_instances      = var.management_instances
  protocol_instances        = var.protocol_instances
  ibm_customer_number       = var.ibm_customer_number
  static_compute_instances  = var.static_compute_instances
  client_instances          = var.client_instances
  enable_cos_integration    = var.enable_cos_integration
  enable_atracker           = var.enable_atracker
  enable_vpc_flow_logs      = var.enable_vpc_flow_logs
  allowed_cidr              = var.allowed_cidr
  vpc_name                  = local.vpc_name
  storage_subnets           = local.storage_subnet
  protocol_subnets          = local.protocol_subnet
  compute_subnets           = local.compute_subnet
  client_subnets            = local.client_subnet
  bastion_subnets           = local.bastion_subnet
  dns_domain_names          = var.dns_domain_names
  bastion_security_group_id = local.bastion_security_group_id
  deployer_hostname         = local.deployer_hostname
  depends_on                = [module.deployer]
}

module "resource_provisioner" {
  source                      = "./modules/resource_provisioner"
  ibmcloud_api_key            = var.ibmcloud_api_key
  enable_deployer             = var.enable_deployer
  bastion_fip                 = local.bastion_fip
  bastion_private_key_content = local.bastion_private_key_content
  deployer_ip                 = local.deployer_ip
  depends_on                  = [module.deployer, module.prepare_tf_input]
}

module "file_storage" {
  count              = var.enable_deployer == false ? 1 : 0
  source             = "./modules/file_storage"
  zone               = var.zones[0] # always the first zone
  resource_group_id  = local.resource_group_ids["service_rg"]
  file_shares        = local.file_shares
  encryption_key_crn = local.boot_volume_encryption_key
  security_group_ids = local.compute_security_group_id
  subnet_id          = local.compute_subnet_id
}

module "dns" {
  count                  = var.enable_deployer == false ? 1 : 0
  source                 = "./modules/dns"
  prefix                 = var.prefix
  resource_group_id      = local.resource_group_ids["service_rg"]
  vpc_crn                = local.vpc_crn
  subnets_crn            = local.subnets_crn
  dns_instance_id        = var.dns_instance_id
  dns_custom_resolver_id = var.dns_custom_resolver_id
  dns_domain_names       = values(var.dns_domain_names)
}

module "compute_dns_records" {
  count           = var.enable_deployer == false ? 1 : 0
  source          = "./modules/dns_record"
  dns_instance_id = local.dns_instance_id
  dns_zone_id     = local.compute_dns_zone_id
  dns_records     = local.compute_dns_records
  depends_on      = [module.dns]
}

module "storage_dns_records" {
  count           = var.enable_deployer == false ? 1 : 0
  source          = "./modules/dns_record"
  dns_instance_id = local.dns_instance_id
  dns_zone_id     = local.storage_dns_zone_id
  dns_records     = local.storage_dns_records
  depends_on      = [module.dns]
}

module "protocol_dns_records" {
  count           = var.enable_deployer == false ? 1 : 0
  source          = "./modules/dns_record"
  dns_instance_id = local.dns_instance_id
  dns_zone_id     = local.protocol_dns_zone_id
  dns_records     = local.protocol_dns_records
  depends_on      = [module.dns]
}

resource "time_sleep" "wait_60_seconds" {
  create_duration = "60s"
  depends_on      = [module.storage_dns_records, module.protocol_dns_records, module.compute_dns_records]
}

module "write_compute_cluster_inventory" {
  count                 = var.enable_deployer == false ? 1 : 0
  source                = "./modules/write_inventory"
  json_inventory_path   = local.json_inventory_path
  lsf_masters           = local.management_nodes
  lsf_servers           = local.compute_nodes_list
  lsf_clients           = local.client_nodes
  gui_hosts             = local.gui_hosts
  db_hosts              = local.db_hosts
  my_cluster_name       = var.prefix
  ha_shared_dir         = local.ha_shared_dir
  nfs_install_dir       = local.nfs_install_dir
  enable_monitoring     = local.enable_monitoring
  lsf_deployer_hostname = local.lsf_deployer_hostname
  depends_on            = [time_sleep.wait_60_seconds]
}

module "write_storage_cluster_inventory" {
  count                 = var.enable_deployer == false ? 1 : 0
  source                = "./modules/write_inventory"
  json_inventory_path   = local.json_inventory_path
  lsf_masters           = local.management_nodes
  lsf_servers           = local.compute_nodes_list
  lsf_clients           = local.client_nodes
  gui_hosts             = local.gui_hosts
  db_hosts              = local.db_hosts
  my_cluster_name       = var.prefix
  ha_shared_dir         = local.ha_shared_dir
  nfs_install_dir       = local.nfs_install_dir
  enable_monitoring     = local.enable_monitoring
  lsf_deployer_hostname = local.lsf_deployer_hostname
  depends_on            = [time_sleep.wait_60_seconds]
}

module "compute_inventory" {
  count               = var.enable_deployer == false ? 1 : 0
  source              = "./modules/inventory"
  hosts               = local.compute_hosts
  inventory_path      = local.compute_inventory_path
  name_mount_path_map = local.fileshare_name_mount_path_map
  depends_on          = [module.write_compute_cluster_inventory]
}

module "storage_inventory" {
  count               = var.enable_deployer == false ? 1 : 0
  source              = "./modules/inventory"
  hosts               = local.storage_hosts
  inventory_path      = local.storage_inventory_path
  name_mount_path_map = local.fileshare_name_mount_path_map
  depends_on          = [module.write_storage_cluster_inventory]
}

module "compute_playbook" {
  count            = var.enable_deployer == false ? 1 : 0
  source           = "./modules/playbook"
  bastion_fip      = local.bastion_fip
  private_key_path = local.compute_private_key_path
  inventory_path   = local.compute_inventory_path
  playbook_path    = local.compute_playbook_path
  enable_bastion   = var.enable_bastion
  depends_on       = [module.compute_inventory]
}

# module "storage_playbook" {
#   count            = var.enable_deployer == false ? 1 : 0
#   source           = "./modules/playbook"
#   bastion_fip      = local.bastion_fip
#   private_key_path = local.storage_private_key_path
#   inventory_path   = local.storage_inventory_path
#   playbook_path    = local.storage_playbook_path
#   enable_bastion   = var.enable_bastion
#   depends_on       = [ module.storage_inventory ]
# }

###################################################
# Observability Modules
###################################################

module "cloud_monitoring_instance_creation" {
  source                         = "./modules/observability_instance"
  enable_deployer                = var.enable_deployer
  location                       = local.region
  rg                             = local.resource_group_ids["service_rg"]
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
  count                   = var.enable_deployer == true && var.scc_enable ? 1 : 0
  source                  = "./modules/security/scc"
  location                = var.scc_location != "" ? var.scc_location : "us-south"
  rg                      = local.resource_group_ids["service_rg"]
  scc_profile             = var.scc_enable ? var.scc_profile : ""
  event_notification_plan = var.scc_event_notification_plan
  tags                    = ["hpc", var.prefix]
  prefix                  = var.prefix
  cos_bucket              = [for name in module.landing_zone.cos_buckets_names : name if strcontains(name, "scc-bucket")][0]
  cos_instance_crn        = module.landing_zone.cos_instance_crns[0]
  # scc_profile_version     = var.scc_profile != "" && var.scc_profile != null ? var.scc_profile_version : ""

}
