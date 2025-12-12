module "landing_zone" {
  source                                        = "./modules/landing_zone"
  enable_landing_zone                           = var.enable_landing_zone
  scheduler                                     = var.scheduler
  vpc_cluster_private_subnets_cidr_blocks       = [var.vpc_cluster_private_subnets_cidr_blocks]
  cos_instance_name                             = var.cos_instance_name
  bastion_subnet_id                             = local.bastion_subnet_id
  compute_subnet_id                             = local.compute_subnet_id
  protocol_subnet_id                            = local.protocol_subnet_id
  client_subnet_id                              = local.client_subnet_id
  storage_subnet_id                             = local.storage_subnet_id
  enable_atracker                               = var.observability_atracker_enable && (var.observability_atracker_target_type == "cos") ? true : false
  enable_cos_integration                        = var.enable_cos_integration
  enable_vpc_flow_logs                          = var.enable_vpc_flow_logs
  key_management                                = local.key_management
  kms_instance_name                             = var.kms_instance_name
  kms_key_name                                  = var.kms_key_name
  ssh_keys                                      = var.ssh_keys
  vpc_cluster_login_private_subnets_cidr_blocks = var.vpc_cluster_login_private_subnets_cidr_blocks
  management_instances                          = var.management_instances
  compute_instances                             = var.static_compute_instances
  cluster_cidr                                  = local.cluster_cidr
  placement_strategy                            = var.placement_strategy
  prefix                                        = var.cluster_prefix
  protocol_instances                            = var.protocol_instances
  protocol_subnets_cidr                         = var.protocol_subnets_cidr
  existing_resource_group                       = var.existing_resource_group
  storage_instances                             = var.storage_instances
  storage_servers                               = var.storage_servers
  storage_subnets_cidr                          = var.storage_subnets_cidr
  storage_type                                  = var.storage_type
  client_instances                              = var.client_instances
  client_subnets_cidr                           = var.client_subnets_cidr
  vpc_name                                      = var.vpc_name
  zones                                         = var.zones
  enable_vpn                                    = var.vpn_enabled
  skip_flowlogs_s2s_auth_policy                 = var.skip_flowlogs_s2s_auth_policy
  skip_kms_s2s_auth_policy                      = var.skip_kms_s2s_auth_policy
  observability_logs_enable                     = var.observability_logs_enable_for_management || var.observability_logs_enable_for_compute || (var.observability_atracker_enable && var.observability_atracker_target_type == "cloudlogs") ? true : false
  scale_encryption_type                         = var.scale_encryption_type
  scale_encryption_enabled                      = var.scale_encryption_enabled
  key_protect_instance_id                       = var.key_protect_instance_id
  afm_instances                                 = var.afm_instances
  afm_cos_config                                = var.afm_cos_config
  filesystem_config                             = var.filesystem_config
  enable_private_path_nlb                       = var.enable_private_path_nlb
  # hpcs_instance_name            = var.hpcs_instance_name
  # clusters                      = var.clusters
}

module "deployer" {
  source                             = "./modules/deployer"
  scheduler                          = var.scheduler
  resource_group                     = local.resource_group_ids["workload_rg"]
  prefix                             = var.cluster_prefix
  vpc_id                             = local.vpc_id
  zones                              = var.zones
  cluster_cidr                       = local.cluster_cidr
  ext_login_subnet_id                = var.login_subnet_id
  bastion_subnets                    = local.login_subnets
  ext_compute_subnet_id              = var.compute_subnet_id
  compute_subnets                    = local.compute_subnets
  client_subnets                     = local.client_subnets
  storage_subnets                    = local.storage_subnets
  protocol_subnets                   = local.protocol_subnets
  bastion_instance                   = var.bastion_instance
  enable_deployer                    = var.enable_deployer
  deployer_instance                  = var.deployer_instance
  ssh_keys                           = var.ssh_keys
  allowed_cidr                       = var.remote_allowed_ips
  kms_encryption_enabled             = local.kms_encryption_enabled
  boot_volume_encryption_key         = local.boot_volume_encryption_key
  dns_domain_names                   = var.dns_domain_names
  skip_iam_authorization_policy      = var.skip_iam_block_storage_authorization_policy
  ext_vpc_name                       = var.vpc_name
  bastion_instance_name              = var.existing_bastion_instance_name
  bastion_instance_public_ip         = local.bastion_instance_public_ip
  existing_bastion_security_group_id = var.existing_bastion_instance_name != null ? var.existing_bastion_security_group_id : null
  ext_client_subnet_id               = var.client_subnet_id
  ext_storage_subnet_id              = var.storage_subnet_id
  ext_protocol_subnet_id             = var.protocol_subnet_id
  login_security_group_name          = var.login_security_group_name
}

module "landing_zone_vsi" {
  count                         = var.enable_deployer == false ? 1 : 0
  source                        = "./modules/landing_zone_vsi"
  resource_group                = var.resource_group_ids["workload_rg"]
  prefix                        = var.cluster_prefix
  vpc_id                        = local.vpc_id
  zones                         = var.zones
  bastion_security_group_id     = var.bastion_security_group_id
  bastion_public_key_content    = local.bastion_public_key_content
  ssh_keys                      = var.ssh_keys
  client_subnets                = local.client_subnets
  client_instances              = var.client_instances
  compute_subnet_id             = local.compute_subnets
  management_instances          = var.management_instances
  static_compute_instances      = var.static_compute_instances
  dynamic_compute_instances     = var.dynamic_compute_instances
  storage_subnets               = local.storage_subnets
  storage_instances             = var.storage_instances
  storage_servers               = var.storage_servers
  storage_type                  = var.storage_type
  protocol_subnets              = local.protocol_subnets
  protocol_instances            = var.protocol_instances
  dns_domain_names              = var.dns_domain_names
  kms_encryption_enabled        = local.kms_encryption_enabled
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  enable_deployer               = var.enable_deployer
  afm_instances                 = var.afm_instances
  enable_dedicated_host         = var.enable_dedicated_host
  enable_ldap                   = var.enable_ldap
  ldap_instances                = var.ldap_instance
  ldap_server                   = local.ldap_server
  scale_encryption_enabled      = var.scale_encryption_enabled
  scale_encryption_type         = var.scale_encryption_type
  gklm_instances                = var.gklm_instances
  vpc_region                    = local.region
  scheduler                     = var.scheduler
  ibm_customer_number           = var.ibm_customer_number
  colocate_protocol_instances   = var.colocate_protocol_instances
  storage_security_group_id     = var.storage_security_group_id
  mtu_value                     = var.mtu_value
  login_instance                = var.login_instance
  bastion_subnets               = local.login_subnets
  cluster_cidr                  = local.cluster_cidr
  bms_boot_drive_encryption     = var.bms_boot_drive_encryption
  tie_breaker_bm_server_profile = var.tie_breaker_bm_server_profile
  scale_management_vsi_profile  = var.scale_management_vsi_profile
  login_security_group_name     = var.login_security_group_name
  storage_security_group_name   = var.storage_security_group_name
  compute_security_group_name   = var.compute_security_group_name
  client_security_group_name    = var.client_security_group_name
  gklm_security_group_name      = var.gklm_security_group_name
  ldap_security_group_name      = var.ldap_security_group_name
  volume_storages               = var.volume_storages
  lsf_pay_per_use               = var.lsf_pay_per_use
  protocol_instance_eth1_mtu    = var.protocol_instance_eth1_mtu
}

module "prepare_tf_input" {
  source                                           = "./modules/prepare_tf_input"
  scheduler                                        = var.scheduler
  enable_deployer                                  = var.enable_deployer
  deployer_ip                                      = local.deployer_ip
  bastion_fip                                      = local.bastion_fip
  ibmcloud_api_key                                 = var.ibmcloud_api_key
  app_center_gui_password                          = var.app_center_gui_password
  lsf_version                                      = var.lsf_version
  resource_group_ids                               = local.resource_group_ids
  cluster_prefix                                   = var.cluster_prefix
  zones                                            = var.zones
  ssh_keys                                         = local.ssh_keys
  storage_instances                                = var.storage_instances
  storage_servers                                  = var.storage_servers
  storage_type                                     = var.storage_type
  management_instances                             = var.management_instances
  protocol_instances                               = var.protocol_instances
  colocate_protocol_instances                      = var.colocate_protocol_instances
  ibm_customer_number                              = var.ibm_customer_number
  static_compute_instances                         = var.static_compute_instances
  dynamic_compute_instances                        = var.dynamic_compute_instances
  client_instances                                 = var.client_instances
  enable_cos_integration                           = var.enable_cos_integration
  enable_atracker                                  = var.enable_atracker
  enable_vpc_flow_logs                             = var.enable_vpc_flow_logs
  enable_dedicated_host                            = var.enable_dedicated_host
  remote_allowed_ips                               = var.remote_allowed_ips
  vpc_name                                         = local.vpc_name
  compute_subnet_id                                = local.compute_subnet
  login_subnet_id                                  = local.login_subnet
  client_subnet_id                                 = local.client_subnet
  storage_subnet_id                                = local.storage_subnet
  protocol_subnet_id                               = local.protocol_subnet
  login_instance                                   = var.login_instance
  dns_domain_names                                 = var.dns_domain_names
  key_management                                   = local.key_management
  kms_instance_name                                = var.kms_instance_name
  kms_key_name                                     = var.kms_key_name
  boot_volume_encryption_key                       = local.boot_volume_encryption_key
  existing_kms_instance_guid                       = local.existing_kms_instance_guid
  skip_iam_share_authorization_policy              = var.skip_iam_share_authorization_policy
  dns_custom_resolver_id                           = var.dns_custom_resolver_id
  dns_instance_id                                  = var.dns_instance_id
  bastion_security_group_id                        = local.bastion_security_group_id
  deployer_hostname                                = local.deployer_hostname
  enable_hyperthreading                            = var.enable_hyperthreading
  cloud_logs_data_bucket                           = local.cloud_logs_data_bucket
  cloud_metrics_data_bucket                        = local.cloud_metrics_data_bucket
  observability_logs_enable_for_management         = var.observability_logs_enable_for_management
  observability_logs_enable_for_compute            = var.observability_logs_enable_for_compute
  observability_enable_platform_logs               = var.observability_enable_platform_logs
  observability_monitoring_enable                  = var.observability_monitoring_enable
  observability_monitoring_plan                    = var.observability_monitoring_plan
  observability_logs_retention_period              = var.observability_logs_retention_period
  observability_monitoring_on_compute_nodes_enable = var.observability_monitoring_on_compute_nodes_enable
  observability_enable_metrics_routing             = var.observability_enable_metrics_routing
  observability_atracker_enable                    = var.observability_atracker_enable
  observability_atracker_target_type               = var.observability_atracker_target_type
  enable_ldap                                      = var.enable_ldap
  ldap_instance                                    = var.ldap_instance
  ldap_server                                      = local.ldap_server
  ldap_basedns                                     = var.ldap_basedns
  ldap_server_cert                                 = local.ldap_server_cert
  ldap_admin_password                              = local.ldap_admin_password
  ldap_user_password                               = var.ldap_user_password
  ldap_user_name                                   = var.ldap_user_name
  afm_instances                                    = var.afm_instances
  afm_cos_config                                   = var.afm_cos_config
  gklm_instances                                   = var.gklm_instances
  scale_encryption_type                            = var.scale_encryption_type
  filesystem_config                                = var.filesystem_config
  filesets_config                                  = var.filesets_config
  storage_gui_username                             = var.storage_gui_username
  storage_gui_password                             = var.storage_gui_password
  compute_gui_username                             = var.compute_gui_username
  compute_gui_password                             = var.compute_gui_password
  scale_encryption_admin_password                  = var.scale_encryption_admin_password
  scale_encryption_enabled                         = var.scale_encryption_enabled
  key_protect_instance_id                          = var.key_protect_instance_id
  storage_security_group_id                        = var.storage_security_group_id
  custom_file_shares                               = var.custom_file_shares
  existing_bastion_instance_name                   = var.existing_bastion_instance_name
  existing_bastion_security_group_id               = var.existing_bastion_security_group_id
  vpc_cluster_private_subnets_cidr_blocks          = var.vpc_cluster_private_subnets_cidr_blocks
  sccwp_enable                                     = var.sccwp_enable
  sccwp_service_plan                               = var.sccwp_service_plan
  cspm_enabled                                     = var.cspm_enabled
  app_config_plan                                  = var.app_config_plan
  existing_resource_group                          = var.existing_resource_group
  tie_breaker_bm_server_profile                    = var.tie_breaker_bm_server_profile
  scale_management_vsi_profile                     = var.scale_management_vsi_profile
  login_security_group_name                        = var.login_security_group_name
  storage_security_group_name                      = var.storage_security_group_name
  compute_security_group_name                      = var.compute_security_group_name
  client_security_group_name                       = var.client_security_group_name
  gklm_security_group_name                         = var.gklm_security_group_name
  ldap_security_group_name                         = var.ldap_security_group_name
  bms_boot_drive_encryption                        = var.bms_boot_drive_encryption
  scale_afm_bucket_config_details                  = local.scale_afm_bucket_config_details
  scale_afm_cos_hmac_key_params                    = local.scale_afm_cos_hmac_key_params
  volume_storages                                  = var.volume_storages
  enable_private_path_nlb                          = var.enable_private_path_nlb
  lsf_pay_per_use                                  = var.lsf_pay_per_use
  protocol_instance_eth1_mtu                       = var.protocol_instance_eth1_mtu
  mtu_value                                        = var.mtu_value
  depends_on                                       = [module.deployer]
}

module "validate_ldap_server_connection" {
  count                       = var.enable_deployer && var.enable_ldap && local.ldap_server != "null" ? 1 : 0
  source                      = "./modules/ldap_remote_exec"
  ldap_server                 = local.ldap_server
  bastion_fip                 = local.bastion_fip
  bastion_private_key_content = local.bastion_ssh_private_key != null ? local.bastion_ssh_private_key : local.bastion_private_key_content
  deployer_ip                 = local.deployer_ip
  depends_on                  = [module.deployer]
}

module "resource_provisioner" {
  source                         = "./modules/resource_provisioner"
  ibmcloud_api_key               = var.ibmcloud_api_key
  enable_deployer                = var.enable_deployer
  cluster_prefix                 = var.cluster_prefix
  bastion_fip                    = local.bastion_fip
  bastion_private_key_content    = local.bastion_ssh_private_key != null ? local.bastion_ssh_private_key : local.bastion_private_key_content
  deployer_ip                    = local.deployer_ip
  scheduler                      = var.scheduler
  existing_bastion_instance_name = var.existing_bastion_instance_name
  bastion_public_key_content     = local.bastion_public_key_content
  depends_on                     = [module.deployer, module.prepare_tf_input, module.validate_ldap_server_connection]
}

module "file_storage" {
  count                               = var.enable_deployer == false && var.scheduler == "LSF" ? 1 : 0
  source                              = "./modules/file_storage"
  zone                                = var.zones[0] # always the first zone
  resource_group_id                   = var.resource_group_ids["workload_rg"]
  file_shares                         = local.file_shares
  encryption_key_crn                  = var.boot_volume_encryption_key
  security_group_ids                  = local.compute_security_group_id
  subnet_id                           = local.compute_subnet
  existing_kms_instance_guid          = var.existing_kms_instance_guid
  skip_iam_share_authorization_policy = var.skip_iam_share_authorization_policy
  kms_encryption_enabled              = local.kms_encryption_enabled
}

module "dns" {
  count                  = var.enable_deployer == false ? 1 : 0
  source                 = "./modules/dns"
  prefix                 = var.cluster_prefix
  resource_group_id      = var.resource_group_ids["service_rg"]
  vpc_crn                = local.vpc_crn
  subnets_crn            = local.subnets_crn
  dns_instance_id        = var.dns_instance_id
  dns_custom_resolver_id = var.dns_custom_resolver_id
  dns_domain_names       = compact(values(var.dns_domain_names))
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
  count           = var.enable_deployer == false && length(var.storage_instances) > 0 ? 1 : 0
  source          = "./modules/dns_record"
  dns_instance_id = local.dns_instance_id
  dns_zone_id     = local.storage_dns_zone_id
  dns_records     = local.storage_dns_records
  depends_on      = [module.dns]
}

module "protocol_reserved_ip" {
  count                   = var.scheduler == "Scale" && var.enable_deployer == false && var.protocol_subnet_id != null ? 1 : 0
  source                  = "./modules/protocol_reserved_ip"
  total_reserved_ips      = local.protocol_instance_count
  subnet_id               = [local.protocol_subnets[0].id]
  name                    = format("%s-ces", var.cluster_prefix)
  protocol_domain         = var.dns_domain_names["protocol"]
  protocol_dns_service_id = local.dns_instance_id
  protocol_dns_zone_id    = local.protocol_dns_zone_id
  enable_private_path_nlb = var.enable_private_path_nlb
  depends_on              = [module.dns]
}

module "private_path_nlb" {
  count                              = var.scheduler == "Scale" && var.enable_deployer == false && var.enable_private_path_nlb == true ? 1 : 0
  source                             = "./modules/private_path_nlb"
  private_path_name                  = format("%s-pp", var.cluster_prefix)
  nlb_name                           = format("%s-ppnlb", var.cluster_prefix)
  resource_group_id                  = var.resource_group_ids["service_rg"]
  subnet_id                          = local.client_subnet
  private_path_service_endpoints     = ["${var.cluster_prefix}.${var.dns_domain_names["ppnlb"]}"]
  nlb_backend_pools                  = local.nlb_backend_pools
  private_path_default_access_policy = "permit"
  private_path_zonal_affinity        = true
  private_path_publish               = true
  private_path_account_policies      = local.private_path_account_policies
  tags                               = [local.scheduler_lowercase, var.cluster_prefix]
  access_tags                        = []
}

module "vpe" {
  count                = var.scheduler == "Scale" && var.enable_deployer == false && var.enable_private_path_nlb == true ? 1 : 0
  source               = "./modules/vpe"
  region               = local.region
  resource_group_id    = var.resource_group_ids["service_rg"]
  prefix               = var.cluster_prefix
  vpc_name             = local.vpc_name
  vpc_id               = local.vpc_id
  subnet_zone_list     = local.client_subnets
  security_group_ids   = length(local.client_security_group_id) > 0 ? local.client_security_group_id : [local.vpc_default_security_group]
  cloud_services       = []
  cloud_service_by_crn = local.cloud_service_by_crn
  service_endpoints    = "private"
  reserved_ips         = {}
  depends_on           = [module.landing_zone_vsi, module.private_path_nlb]
}

module "client_dns_records" {
  count           = var.enable_deployer == false && length(var.client_instances) > 0 ? 1 : 0
  source          = "./modules/dns_record"
  dns_instance_id = local.dns_instance_id
  dns_zone_id     = local.client_dns_zone_id
  dns_records     = local.client_dns_records
  depends_on      = [module.dns]
}

module "gklm_dns_records" {
  count           = var.enable_deployer == false && length(var.gklm_instances) > 0 ? 1 : 0
  source          = "./modules/dns_record"
  dns_instance_id = local.dns_instance_id
  dns_zone_id     = local.gklm_dns_zone_id
  dns_records     = local.gklm_dns_records
  depends_on      = [module.dns]
}

resource "time_sleep" "wait_for_vsi_syncup" {
  count           = var.enable_deployer == false && var.scheduler == "Scale" && var.storage_type != "baremetal" && (can(regex("^ibm-redhat-8-10-minimal-amd64-.*$", (var.storage_instances[*]["image"])[0])) || local.enable_sec_interface_compute || local.enable_sec_interface_storage) ? 1 : 0
  create_duration = local.enable_sec_interface_compute || local.enable_sec_interface_storage ? "180s" : "300s"
  depends_on      = [module.storage_dns_records, module.protocol_reserved_ip, module.compute_dns_records, module.landing_zone_vsi]
}

module "write_compute_cluster_inventory" {
  count                       = var.enable_deployer == false ? 1 : 0
  source                      = "./modules/write_inventory"
  json_inventory_path         = local.json_inventory_path
  lsf_masters                 = local.management_nodes
  lsf_servers                 = local.compute_nodes_list
  lsf_clients                 = local.client_nodes
  gui_hosts                   = local.gui_hosts
  db_hosts                    = local.db_hosts
  login_host                  = local.login_host
  prefix                      = var.cluster_prefix
  ha_shared_dir               = local.ha_shared_dir
  nfs_install_dir             = local.nfs_install_dir
  enable_monitoring           = local.enable_monitoring
  lsf_deployer_hostname       = local.lsf_deployer_hostname
  ibmcloud_api_key            = var.ibmcloud_api_key
  app_center_gui_password     = var.app_center_gui_password
  lsf_version                 = var.lsf_version
  dns_domain_names            = var.dns_domain_names
  compute_public_key_content  = local.compute_public_key_content
  compute_private_key_content = local.compute_private_key_content
  enable_hyperthreading       = var.enable_hyperthreading
  compute_subnet_id           = local.compute_subnet_id
  region                      = local.region
  resource_group_id           = var.resource_group_ids["service_rg"]
  zones                       = var.zones
  vpc_id                      = local.vpc_id
  compute_subnets_cidr        = var.compute_subnet_id != null ? [data.ibm_is_subnet.existing_compute_subnets_cidr[0].ipv4_cidr_block] : [var.vpc_cluster_private_subnets_cidr_blocks]
  dynamic_compute_instances   = var.dynamic_compute_instances
  compute_security_group_id   = local.compute_security_group_id
  compute_ssh_keys_ids        = local.ssh_keys_ids
  compute_subnet_crn          = local.compute_subnet_crn
  kms_encryption_enabled      = local.kms_encryption_enabled
  boot_volume_encryption_key  = var.boot_volume_encryption_key
  lsf_pay_per_use             = var.lsf_pay_per_use
  mtu_value                   = var.mtu_value
  depends_on                  = [time_sleep.wait_for_vsi_syncup, module.landing_zone_vsi]
}

module "write_compute_scale_cluster_inventory" {
  count                                            = var.scheduler == "Scale" && var.enable_deployer == false ? 1 : 0
  source                                           = "./modules/write_scale_inventory"
  json_inventory_path                              = var.scheduler == "Scale" ? format("%s/compute_cluster_inventory.json", var.scale_ansible_repo_clone_path) : format("%s/compute_cluster_inventory.json", local.json_inventory_path)
  bastion_user                                     = jsonencode(var.bastion_user)
  bastion_instance_id                              = var.bastion_instance_id == null ? jsonencode("None") : jsonencode(var.bastion_instance_id)
  bastion_instance_public_ip                       = var.bastion_fip == null ? jsonencode("None") : jsonencode(var.bastion_fip)
  cloud_platform                                   = jsonencode("IBMCloud")
  resource_prefix                                  = jsonencode(format("%s.%s", var.cluster_prefix, var.dns_domain_names["compute"]))
  vpc_region                                       = jsonencode(local.region)
  vpc_availability_zones                           = var.zones
  scale_version                                    = jsonencode(local.scale_version)
  compute_cluster_filesystem_mountpoint            = jsonencode((var.static_compute_instances[*].filesystem)[0])
  storage_cluster_filesystem_mountpoint            = jsonencode("None")
  filesystem_block_size                            = jsonencode("None")
  compute_cluster_instance_private_ips             = concat(local.compute_instance_private_ips, local.compute_mgmt_instance_private_ips)
  compute_cluster_instance_ids                     = concat(local.compute_instance_ids, local.compute_mgmt_instance_ids)
  compute_cluster_instance_names                   = concat(local.compute_instance_names, local.compute_mgmt_instance_names)
  compute_cluster_instance_private_dns_ip_map      = {}
  storage_cluster_instance_ids                     = []
  storage_cluster_instance_private_ips             = []
  storage_cluster_with_data_volume_mapping         = {}
  storage_cluster_instance_private_dns_ip_map      = {}
  storage_cluster_desc_instance_ids                = []
  storage_cluster_desc_instance_private_ips        = []
  storage_cluster_desc_data_volume_mapping         = {}
  storage_cluster_desc_instance_private_dns_ip_map = {}
  storage_cluster_instance_names                   = []
  storage_subnet_cidr                              = local.enable_mrot_conf ? local.storage_subnet_cidr : jsonencode("")
  compute_subnet_cidr                              = local.enable_mrot_conf ? local.compute_subnet_cidr : jsonencode("")
  scale_remote_cluster_clustername                 = local.enable_mrot_conf ? jsonencode(format("%s.%s", var.cluster_prefix, var.dns_domain_names["storage"])) : jsonencode("")
  protocol_cluster_instance_names                  = []
  client_cluster_instance_names                    = []
  protocol_cluster_reserved_names                  = ""
  smb                                              = false
  nfs                                              = true
  object                                           = false
  interface                                        = []
  export_ip_pool                                   = []
  filesystem                                       = jsonencode("")
  mountpoint                                       = jsonencode("")
  protocol_gateway_ip                              = jsonencode("")
  filesets                                         = local.fileset_size_map
  afm_cos_bucket_details                           = []
  afm_config_details                               = []
  afm_cluster_instance_names                       = []
  filesystem_mountpoint                            = local.encryption_filesystem_mountpoint
  depends_on                                       = [time_sleep.wait_for_vsi_syncup, module.landing_zone_vsi]
}

module "write_storage_scale_cluster_inventory" {
  count                                            = var.scheduler == "Scale" && var.enable_deployer == false ? 1 : 0
  source                                           = "./modules/write_scale_inventory"
  json_inventory_path                              = format("%s/storage_cluster_inventory.json", var.scale_ansible_repo_clone_path)
  bastion_user                                     = jsonencode(var.bastion_user)
  bastion_instance_id                              = var.bastion_instance_id == null ? jsonencode("None") : jsonencode(var.bastion_instance_id)
  bastion_instance_public_ip                       = var.bastion_fip == null ? jsonencode("None") : jsonencode(var.bastion_fip)
  cloud_platform                                   = jsonencode("IBMCloud")
  resource_prefix                                  = jsonencode(format("%s.%s", var.cluster_prefix, var.dns_domain_names["storage"]))
  vpc_region                                       = jsonencode(local.region)
  vpc_availability_zones                           = var.zones
  scale_version                                    = jsonencode(local.scale_version)
  compute_cluster_filesystem_mountpoint            = jsonencode("None")
  storage_cluster_filesystem_mountpoint            = jsonencode(local.filesystem_mountpoint)
  filesystem_block_size                            = jsonencode(var.filesystem_config[0]["block_size"])
  compute_cluster_instance_ids                     = []
  compute_cluster_instance_private_ips             = []
  compute_cluster_instance_private_dns_ip_map      = {}
  compute_cluster_instance_names                   = []
  storage_cluster_instance_ids                     = var.storage_type == "baremetal" ? concat(local.baremetal_cluster_instance_ids, local.strg_mgmtt_instance_ids, local.bm_tie_breaker_ids) : concat(local.storage_cluster_instance_ids, local.strg_mgmtt_instance_ids, local.tie_breaker_storage_instance_ids)
  storage_cluster_instance_private_ips             = var.storage_type == "baremetal" ? concat(local.baremetal_cluster_instance_private_ips, local.strg_mgmt_instance_private_ips, local.bm_tie_breaker_private_ips) : concat(local.storage_cluster_instance_private_ips, local.strg_mgmt_instance_private_ips, local.tie_breaker_storage_instance_private_ips)
  storage_cluster_instance_names                   = var.storage_type == "baremetal" ? concat(local.baremetal_cluster_instance_names, local.strg_mgmt_instance_names, local.bm_tie_breaker_names) : concat(local.storage_cluster_instance_names, local.strg_mgmt_instance_names, local.tie_breaker_storage_instance_names)
  storage_cluster_with_data_volume_mapping         = local.storage_ips_with_vol_mapping[0]
  storage_cluster_instance_private_dns_ip_map      = {}
  storage_cluster_desc_instance_private_ips        = local.strg_tie_breaker_private_ips
  storage_cluster_desc_instance_ids                = local.strg_tie_breaker_instance_ids
  storage_cluster_desc_data_volume_mapping         = local.tie_breaker_ips_with_vol_mapping[0]
  storage_cluster_desc_instance_private_dns_ip_map = {}
  storage_subnet_cidr                              = local.enable_mrot_conf ? local.storage_subnet_cidr : jsonencode("")
  compute_subnet_cidr                              = local.enable_mrot_conf ? local.compute_subnet_cidr : local.scale_ces_enabled == true && local.client_instance_count > 0 ? local.client_subnet_cidr : jsonencode("")
  scale_remote_cluster_clustername                 = local.enable_mrot_conf ? jsonencode(format("%s.%s", var.cluster_prefix, var.dns_domain_names["compute"])) : jsonencode("")
  protocol_cluster_instance_names                  = local.scale_ces_enabled == true ? local.protocol_cluster_instance_names : []
  client_cluster_instance_names                    = []
  protocol_cluster_reserved_names                  = ""
  smb                                              = false
  nfs                                              = local.scale_ces_enabled == true ? true : false
  object                                           = false
  interface                                        = []
  export_ip_pool                                   = local.scale_ces_enabled == true ? values(one(module.protocol_reserved_ip[*].instance_name_ip_map)) : []
  filesystem                                       = local.scale_ces_enabled == true ? jsonencode("cesSharedRoot") : jsonencode("")
  mountpoint                                       = local.scale_ces_enabled == true ? jsonencode(local.filesystem_mountpoint) : jsonencode("")
  protocol_gateway_ip                              = jsonencode(local.protocol_subnet_gateway_ip)
  filesets                                         = local.fileset_size_map
  afm_config_details                               = var.scale_afm_bucket_config_details
  afm_cos_bucket_details                           = var.scale_afm_cos_hmac_key_params
  afm_cluster_instance_names                       = local.afm_names_final
  filesystem_mountpoint                            = local.encryption_filesystem_mountpoint
  boot_volume_disk_grow                            = local.boot_volume_disk_grow
  block_volume_disk_grow                           = local.block_volume_disk_grow
  depends_on                                       = [time_sleep.wait_for_vsi_syncup, module.landing_zone_vsi]
}

module "write_client_scale_cluster_inventory" {
  count                                            = var.scheduler == "Scale" && var.enable_deployer == false ? 1 : 0
  source                                           = "./modules/write_scale_inventory"
  json_inventory_path                              = format("%s/client_cluster_inventory.json", var.scale_ansible_repo_clone_path)
  bastion_user                                     = jsonencode(var.bastion_user)
  bastion_instance_id                              = var.bastion_instance_id == null ? jsonencode("None") : jsonencode(var.bastion_instance_id)
  bastion_instance_public_ip                       = var.bastion_fip == null ? jsonencode("None") : jsonencode(var.bastion_fip)
  cloud_platform                                   = jsonencode("")
  resource_prefix                                  = jsonencode("")
  vpc_region                                       = jsonencode("")
  vpc_availability_zones                           = []
  scale_version                                    = jsonencode("")
  filesystem_block_size                            = jsonencode("")
  compute_cluster_filesystem_mountpoint            = jsonencode("None")
  compute_cluster_instance_ids                     = []
  compute_cluster_instance_private_ips             = []
  compute_cluster_instance_private_dns_ip_map      = {}
  storage_cluster_filesystem_mountpoint            = local.scale_ces_enabled == true ? jsonencode(local.filesystem_mountpoint) : jsonencode("")
  storage_cluster_instance_ids                     = []
  storage_cluster_instance_private_ips             = []
  storage_cluster_with_data_volume_mapping         = {}
  storage_cluster_instance_private_dns_ip_map      = {}
  storage_cluster_desc_instance_ids                = []
  storage_cluster_desc_instance_private_ips        = []
  storage_cluster_desc_data_volume_mapping         = {}
  storage_cluster_desc_instance_private_dns_ip_map = {}
  storage_cluster_instance_names                   = []
  compute_cluster_instance_names                   = []
  storage_subnet_cidr                              = jsonencode("")
  compute_subnet_cidr                              = jsonencode("")
  scale_remote_cluster_clustername                 = jsonencode("")
  protocol_cluster_instance_names                  = []
  client_cluster_instance_names                    = local.scale_ces_enabled == true ? local.client_instance_names : []
  protocol_cluster_reserved_names                  = local.scale_ces_enabled == true ? var.enable_private_path_nlb ? "${var.cluster_prefix}.${var.dns_domain_names["ppnlb"]}" : format("%s-ces.%s", var.cluster_prefix, var.dns_domain_names["protocol"]) : ""
  smb                                              = false
  nfs                                              = false
  object                                           = false
  interface                                        = []
  export_ip_pool                                   = []
  filesystem                                       = jsonencode("")
  mountpoint                                       = jsonencode("")
  protocol_gateway_ip                              = jsonencode("")
  filesets                                         = local.scale_ces_enabled == true ? local.fileset_size_map : {}
  afm_cos_bucket_details                           = []
  afm_config_details                               = []
  afm_cluster_instance_names                       = []
  filesystem_mountpoint                            = jsonencode("")
  depends_on                                       = [time_sleep.wait_for_vsi_syncup, module.landing_zone_vsi]
}

module "key_protect_scale" {
  count                          = var.scale_encryption_enabled == true && var.scale_encryption_type == "key_protect" && var.enable_deployer == false ? 1 : 0
  source                         = "./modules/key_protect"
  key_protect_instance_id        = var.key_protect_instance_id != null ? var.key_protect_instance_id : var.existing_kms_instance_guid
  resource_prefix                = var.cluster_prefix
  vpc_region                     = local.region
  scale_config_path              = format("%s/key_protect", var.scale_config_path)
  vpc_storage_cluster_dns_domain = var.dns_domain_names["storage"]
}

module "ldap_configuration" {
  count                      = var.scheduler == "Scale" && var.enable_deployer == false && var.enable_ldap && var.ldap_server == "null" ? 1 : 0
  source                     = "./modules/common/ldap_configuration"
  turn_on                    = var.enable_ldap
  clone_path                 = var.scale_ansible_repo_clone_path
  create_scale_cluster       = var.create_scale_cluster
  bastion_user               = jsonencode(var.bastion_user)
  write_inventory_complete   = module.write_storage_scale_cluster_inventory[0].write_scale_inventory_complete
  ldap_cluster_prefix        = var.cluster_prefix
  using_jumphost_connection  = var.using_jumphost_connection
  bastion_instance_public_ip = local.bastion_fip
  bastion_ssh_private_key    = local.bastion_ssh_private_key != null ? local.bastion_ssh_private_key : local.bastion_private_key_content
  ldap_basedns               = var.ldap_basedns
  ldap_admin_password        = var.ldap_admin_password
  ldap_user_name             = var.ldap_user_name
  ldap_user_password         = var.ldap_user_password
  ldap_server                = var.enable_ldap ? (var.ldap_server != "null" ? var.ldap_server : local.ldap_instance_private_ips[0]) : null
  meta_private_key           = module.landing_zone_vsi[0].storage_private_key_content
  depends_on                 = [module.validate_ldap_server_connection, module.landing_zone_vsi]
}

module "pre_cluster_setup" {
  count                        = var.scheduler == "Scale" && var.enable_deployer == false ? 1 : 0
  source                       = "./modules/pre_cluster_setup"
  scheduler                    = var.scheduler
  clone_path                   = var.scale_ansible_repo_clone_path
  storage_hosts                = local.storage_host_entry
  storage_mgmnt_hosts          = local.storage_mgmnt_host_entry
  storage_tb_hosts             = local.storage_tb_host_entry
  compute_hosts                = local.compute_host_entry
  compute_mgmnt_hosts          = local.compute_mgmnt_host_entry
  client_hosts                 = local.client_host_entry
  protocol_hosts               = local.protocol_host_entry
  gklm_hosts                   = local.gklm_host_entry
  afm_hosts                    = local.afm_host_entry
  storage_bms_hosts            = local.storage_bms_host_entry
  storage_tb_bms_hosts         = local.storage_tb_bms_host_entry
  protocol_bms_hosts           = local.protocol_bms_host_entry
  afm_bms_hosts                = local.afm_bms_host_entry
  domain_names                 = var.dns_domain_names
  storage_type                 = var.storage_type
  storage_interface            = local.bms_interfaces[0]
  protocol_interface           = local.bms_interfaces[1]
  enable_sec_interface_compute = local.enable_sec_interface_compute
  enable_protocol              = local.enable_protocol && var.colocate_protocol_instances ? true : false
  vpc_region                   = local.region
  resource_group               = var.resource_group_ids["service_rg"]
  protocol_subnets             = local.enable_protocol ? (length(local.protocol_subnets) > 0 ? local.protocol_subnets[0].id : "") : ""
  bms_boot_drive_encryption    = var.bms_boot_drive_encryption
  ibmcloud_api_key             = var.ibmcloud_api_key
  scale_encryption_type        = var.scale_encryption_type
  colocate_protocol_instances  = var.colocate_protocol_instances
  enable_private_path_nlb      = var.enable_private_path_nlb
  protocol_instance_eth1_mtu   = var.protocol_instance_eth1_mtu
  depends_on                   = [module.landing_zone_vsi]
}

module "compute_cluster_configuration" {
  count                           = var.scheduler == "Scale" && var.enable_deployer == false ? 1 : 0
  source                          = "./modules/common/compute_configuration"
  turn_on                         = (var.create_separate_namespaces == true && local.static_compute_instance_count > 0) ? true : false
  bastion_user                    = jsonencode(var.bastion_user)
  write_inventory_complete        = module.write_compute_scale_cluster_inventory[0].write_scale_inventory_complete
  inventory_format                = var.inventory_format
  create_scale_cluster            = var.create_scale_cluster
  clone_path                      = var.scale_ansible_repo_clone_path
  inventory_path                  = format("%s/compute_cluster_inventory.json", var.scale_ansible_repo_clone_path)
  using_packer_image              = var.using_packer_image
  using_jumphost_connection       = var.using_jumphost_connection
  using_rest_initialization       = var.using_rest_api_remote_mount
  compute_cluster_gui_username    = var.compute_gui_username
  compute_cluster_gui_password    = var.compute_gui_password
  comp_memory                     = local.compute_memory
  comp_vcpus_count                = local.compute_vcpus_count
  comp_bandwidth                  = local.compute_bandwidth
  bastion_instance_public_ip      = jsonencode(local.bastion_fip)
  bastion_ssh_private_key         = var.bastion_ssh_private_key
  meta_private_key                = module.landing_zone_vsi[0].compute_private_key_content
  scale_version                   = local.scale_version
  spectrumscale_rpms_path         = var.spectrumscale_rpms_path
  enable_mrot_conf                = local.enable_mrot_conf
  enable_ces                      = false
  enable_afm                      = false
  scale_encryption_type           = var.scale_encryption_type != null ? var.scale_encryption_type : null
  scale_encryption_enabled        = var.scale_encryption_enabled
  scale_encryption_admin_password = var.scale_encryption_admin_password == null ? "null" : var.scale_encryption_admin_password
  scale_encryption_servers        = var.scale_encryption_enabled && var.scale_encryption_type == "gklm" ? local.gklm_instance_private_ips : []
  enable_ldap                     = var.enable_ldap
  ldap_basedns                    = var.ldap_basedns
  ldap_server                     = var.enable_ldap ? (var.ldap_server != "null" ? var.ldap_server : local.ldap_instance_private_ips[0]) : null
  ldap_admin_password             = local.ldap_admin_password == "" ? jsonencode(null) : local.ldap_admin_password
  enable_key_protect              = var.scale_encryption_type == "key_protect" ? "True" : "False"
  depends_on                      = [module.write_compute_scale_cluster_inventory, module.key_protect_scale, module.ldap_configuration, module.pre_cluster_setup]
}

module "storage_cluster_configuration" {
  count                           = var.scheduler == "Scale" && var.enable_deployer == false ? 1 : 0
  source                          = "./modules/common/storage_configuration"
  turn_on                         = (var.create_separate_namespaces == true && local.storage_instance_count > 0) ? true : false
  bastion_user                    = jsonencode(var.bastion_user)
  write_inventory_complete        = module.write_storage_scale_cluster_inventory[0].write_scale_inventory_complete
  inventory_format                = var.inventory_format
  create_scale_cluster            = var.create_scale_cluster
  clone_path                      = var.scale_ansible_repo_clone_path
  scale_config_path               = var.scale_config_path
  inventory_path                  = format("%s/storage_cluster_inventory.json", var.scale_ansible_repo_clone_path)
  using_packer_image              = var.using_packer_image
  using_jumphost_connection       = var.using_jumphost_connection
  using_rest_initialization       = true
  storage_cluster_gui_username    = var.storage_gui_username
  storage_cluster_gui_password    = var.storage_gui_password
  colocate_protocol_instances     = var.colocate_protocol_instances
  is_colocate_protocol_subset     = local.is_colocate_protocol_subset
  mgmt_memory                     = local.management_memory
  mgmt_vcpus_count                = local.management_vcpus_count
  mgmt_bandwidth                  = local.management_bandwidth
  strg_desc_memory                = local.storage_desc_memory
  strg_desc_vcpus_count           = local.storage_desc_vcpus_count
  strg_desc_bandwidth             = local.storage_desc_bandwidth
  strg_memory                     = local.storage_memory
  strg_vcpus_count                = local.storage_vcpus_count
  strg_bandwidth                  = local.storage_bandwidth
  proto_memory                    = local.protocol_memory
  proto_vcpus_count               = local.protocol_vcpus_count
  proto_bandwidth                 = local.protocol_bandwidth
  strg_proto_memory               = local.storage_protocol_memory
  strg_proto_vcpus_count          = local.storage_protocol_vcpus_count
  strg_proto_bandwidth            = local.storage_protocol_bandwidth
  afm_memory                      = local.afm_memory
  afm_vcpus_count                 = local.afm_vcpus_count
  afm_bandwidth                   = local.afm_bandwidth
  disk_type                       = "network-attached"
  max_data_replicas               = var.filesystem_config[0]["max_data_replica"]
  max_metadata_replicas           = var.filesystem_config[0]["max_metadata_replica"]
  default_metadata_replicas       = var.filesystem_config[0]["default_metadata_replica"]
  default_data_replicas           = var.filesystem_config[0]["default_data_replica"]
  bastion_instance_public_ip      = jsonencode(local.bastion_fip)
  bastion_ssh_private_key         = var.bastion_ssh_private_key
  meta_private_key                = module.landing_zone_vsi[0].storage_private_key_content
  scale_version                   = local.scale_version
  spectrumscale_rpms_path         = var.spectrumscale_rpms_path
  enable_mrot_conf                = local.enable_mrot_conf
  enable_ces                      = local.scale_ces_enabled
  enable_afm                      = local.enable_afm
  scale_encryption_enabled        = var.scale_encryption_enabled
  scale_encryption_type           = var.scale_encryption_type != null ? var.scale_encryption_type : null
  scale_encryption_admin_password = var.scale_encryption_admin_password == null ? "null" : var.scale_encryption_admin_password
  scale_encryption_servers        = var.scale_encryption_enabled && var.scale_encryption_type == "gklm" ? local.gklm_instance_private_ips : []
  enable_ldap                     = var.enable_ldap
  ldap_basedns                    = var.ldap_basedns
  ldap_server                     = var.enable_ldap ? (var.ldap_server != "null" ? var.ldap_server : local.ldap_instance_private_ips[0]) : null
  ldap_admin_password             = local.ldap_admin_password == "" ? jsonencode(null) : local.ldap_admin_password
  ldap_server_cert                = local.ldap_server_cert
  enable_key_protect              = var.scale_encryption_type == "key_protect" ? "True" : "False"
  storage_type                    = var.storage_type
  boot_volume_disk_grow           = local.boot_volume_disk_grow
  block_volume_disk_grow          = local.block_volume_disk_grow
  bms_boot_drive_encryption       = var.bms_boot_drive_encryption
  depends_on                      = [module.write_storage_scale_cluster_inventory, module.key_protect_scale, module.ldap_configuration, module.pre_cluster_setup]
}

module "client_configuration" {
  count                           = var.scheduler == "Scale" && var.enable_deployer == false ? 1 : 0
  source                          = "./modules/common/client_configuration"
  turn_on                         = (local.client_instance_count > 0 && var.create_separate_namespaces == true && local.scale_ces_enabled == true) || (local.client_instance_count > 0 && var.create_separate_namespaces == true && var.colocate_protocol_instances) ? true : false
  create_scale_cluster            = var.create_scale_cluster
  storage_cluster_create_complete = module.storage_cluster_configuration[0].storage_cluster_create_complete
  clone_path                      = var.scale_ansible_repo_clone_path
  using_jumphost_connection       = var.using_jumphost_connection
  client_inventory_path           = format("%s/client_cluster_inventory.json", var.scale_ansible_repo_clone_path)
  bastion_user                    = jsonencode(var.bastion_user)
  bastion_instance_public_ip      = jsonencode(local.bastion_fip)
  bastion_ssh_private_key         = var.bastion_ssh_private_key
  client_meta_private_key         = module.landing_zone_vsi[0].client_private_key_content
  write_inventory_complete        = module.write_storage_scale_cluster_inventory[0].write_scale_inventory_complete
  enable_ldap                     = var.enable_ldap
  ldap_basedns                    = var.ldap_basedns
  ldap_server                     = var.enable_ldap ? (var.ldap_server != "null" ? var.ldap_server : local.ldap_instance_private_ips[0]) : null
  ldap_admin_password             = local.ldap_admin_password == "" ? jsonencode(null) : local.ldap_admin_password
  depends_on                      = [module.storage_cluster_configuration, module.ldap_configuration, module.pre_cluster_setup]
}

module "remote_mount_configuration" {
  count                           = var.scheduler == "Scale" && var.enable_deployer == false ? 1 : 0
  source                          = "./modules/common/remote_mount_configuration"
  turn_on                         = (local.static_compute_instance_count > 0 && local.storage_instance_count > 0 && var.create_separate_namespaces == true) ? true : false
  create_scale_cluster            = var.create_scale_cluster
  bastion_user                    = jsonencode(var.bastion_user)
  clone_path                      = var.scale_ansible_repo_clone_path
  compute_inventory_path          = format("%s/compute_cluster_inventory.json", var.scale_ansible_repo_clone_path)
  compute_gui_inventory_path      = format("%s/compute_cluster_gui_details.json", var.scale_ansible_repo_clone_path)
  storage_inventory_path          = format("%s/storage_cluster_inventory.json", var.scale_ansible_repo_clone_path)
  storage_gui_inventory_path      = format("%s/storage_cluster_gui_details.json", var.scale_ansible_repo_clone_path)
  compute_cluster_gui_username    = var.compute_gui_username
  compute_cluster_gui_password    = var.compute_gui_password
  storage_cluster_gui_username    = var.storage_gui_username
  storage_cluster_gui_password    = var.storage_gui_password
  using_jumphost_connection       = var.using_jumphost_connection
  using_rest_initialization       = var.using_rest_api_remote_mount
  bastion_instance_public_ip      = jsonencode(local.bastion_fip)
  bastion_ssh_private_key         = var.bastion_ssh_private_key
  compute_cluster_create_complete = var.enable_deployer ? false : module.compute_cluster_configuration[0].compute_cluster_create_complete
  storage_cluster_create_complete = var.enable_deployer ? false : module.storage_cluster_configuration[0].storage_cluster_create_complete
  depends_on                      = [module.compute_cluster_configuration, module.storage_cluster_configuration]
}

module "invoke_compute_network_playbook" {
  count                           = var.scheduler == "Scale" ? 1 : 0
  source                          = "./modules/common/network_playbook"
  turn_on                         = (var.create_separate_namespaces == true && local.static_compute_instance_count > 0) ? true : false
  create_scale_cluster            = var.create_scale_cluster
  compute_cluster_create_complete = var.enable_deployer ? false : module.compute_cluster_configuration[0].compute_cluster_create_complete
  storage_cluster_create_complete = var.enable_deployer ? false : module.storage_cluster_configuration[0].storage_cluster_create_complete
  inventory_path                  = format("%s/%s/compute_inventory.ini", var.scale_ansible_repo_clone_path, "ibm-spectrum-scale-install-infra")
  network_playbook_path           = format("%s/%s/collections/ansible_collections/ibm/spectrum_scale/samples/playbook_cloud_network_config.yaml", var.scale_ansible_repo_clone_path, "ibm-spectrum-scale-install-infra")
  depends_on                      = [module.compute_cluster_configuration, module.storage_cluster_configuration]
}

module "invoke_storage_network_playbook" {
  count                           = var.scheduler == "Scale" ? 1 : 0
  source                          = "./modules/common/network_playbook"
  turn_on                         = (var.create_separate_namespaces == true && local.storage_instance_count > 0) ? true : false
  create_scale_cluster            = var.create_scale_cluster
  compute_cluster_create_complete = var.enable_deployer ? false : module.compute_cluster_configuration[0].compute_cluster_create_complete
  storage_cluster_create_complete = var.enable_deployer ? false : module.storage_cluster_configuration[0].storage_cluster_create_complete
  inventory_path                  = format("%s/%s/storage_inventory.ini", var.scale_ansible_repo_clone_path, "ibm-spectrum-scale-install-infra")
  network_playbook_path           = format("%s/%s/collections/ansible_collections/ibm/spectrum_scale/samples/playbook_cloud_network_config.yaml", var.scale_ansible_repo_clone_path, "ibm-spectrum-scale-install-infra")
  depends_on                      = [module.compute_cluster_configuration, module.storage_cluster_configuration]
}

module "encryption_configuration" {
  source                                  = "./modules/common/encryption_configuration"
  count                                   = var.scheduler == "Scale" && var.enable_deployer == false && var.scale_encryption_enabled && var.scale_encryption_type == "gklm" ? 1 : 0
  turn_on                                 = (var.create_separate_namespaces == true && local.storage_instance_count > 0) ? true : false
  clone_path                              = var.scale_ansible_repo_clone_path
  create_scale_cluster                    = var.create_scale_cluster
  meta_private_key                        = module.landing_zone_vsi[0].storage_private_key_content
  scale_encryption_type                   = var.scale_encryption_type != null ? var.scale_encryption_type : null
  scale_encryption_admin_password         = var.scale_encryption_admin_password
  scale_encryption_servers                = var.scale_encryption_enabled && var.scale_encryption_type == "gklm" ? local.gklm_instance_private_ips : []
  scale_encryption_servers_dns            = var.scale_encryption_type == "gklm" ? [for instance in local.gklm_instances : "${instance.name}.${var.dns_domain_names["gklm"]}"] : []
  scale_cluster_clustername               = var.cluster_prefix
  scale_encryption_admin_default_password = local.scale_encryption_admin_default_password
  scale_encryption_admin_username         = local.scale_encryption_admin_username
  compute_cluster_create_complete         = module.compute_cluster_configuration[0].compute_cluster_create_complete
  storage_cluster_create_complete         = module.storage_cluster_configuration[0].storage_cluster_create_complete
  remote_mount_create_complete            = module.remote_mount_configuration[0].remote_mount_create_complete
  compute_cluster_encryption              = (var.create_separate_namespaces == true && local.static_compute_instance_count > 0) ? true : false
  storage_cluster_encryption              = (var.create_separate_namespaces == true && local.storage_instance_count > 0) ? true : false
  depends_on                              = [module.client_configuration, module.compute_cluster_configuration, module.storage_cluster_configuration]
}

module "key_protect_encryption_configuration" {
  source                          = "./modules/common/key_protect_configuration"
  count                           = var.scheduler == "Scale" && var.enable_deployer == false && var.scale_encryption_enabled && var.scale_encryption_type == "key_protect" ? 1 : 0
  turn_on                         = (var.create_separate_namespaces == true && local.storage_instance_count > 0) ? true : false
  clone_path                      = var.scale_ansible_repo_clone_path
  create_scale_cluster            = var.create_scale_cluster
  scale_encryption_type           = var.scale_encryption_type != null ? var.scale_encryption_type : null
  compute_cluster_create_complete = module.compute_cluster_configuration[0].compute_cluster_create_complete
  storage_cluster_create_complete = module.storage_cluster_configuration[0].storage_cluster_create_complete
  remote_mount_create_complete    = module.remote_mount_configuration[0].remote_mount_create_complete
  compute_cluster_encryption      = (var.create_separate_namespaces == true && local.static_compute_instance_count > 0) ? true : false
  storage_cluster_encryption      = (var.create_separate_namespaces == true && local.storage_instance_count > 0) ? true : false
  depends_on                      = [module.client_configuration, module.compute_cluster_configuration, module.storage_cluster_configuration]
}

module "compute_inventory" {
  count                               = var.enable_deployer == false ? 1 : 0
  source                              = "./modules/inventory"
  scheduler                           = var.scheduler
  hosts                               = local.compute_hosts
  gui_hosts                           = local.gui_hosts
  login_host                          = local.login_host
  inventory_path                      = local.compute_inventory_path
  name_mount_path_map                 = local.fileshare_name_mount_path_map
  logs_enable_for_management          = var.observability_logs_enable_for_management
  monitoring_enable_for_management    = var.observability_monitoring_enable
  monitoring_enable_for_compute       = var.observability_monitoring_on_compute_nodes_enable
  cloud_monitoring_access_key         = var.observability_monitoring_enable ? module.cloud_monitoring_instance_creation[0].cloud_monitoring_access_key : ""
  cloud_monitoring_ingestion_url      = var.observability_monitoring_enable ? module.cloud_monitoring_instance_creation[0].cloud_monitoring_ingestion_url : ""
  cloud_monitoring_prws_key           = var.observability_monitoring_enable ? module.cloud_monitoring_instance_creation[0].cloud_monitoring_prws_key : ""
  cloud_monitoring_prws_url           = var.observability_monitoring_enable ? module.cloud_monitoring_instance_creation[0].cloud_monitoring_prws_url : ""
  logs_enable_for_compute             = var.observability_logs_enable_for_compute
  cloud_logs_ingress_private_endpoint = local.cloud_logs_ingress_private_endpoint
  ha_shared_dir                       = local.ha_shared_dir
  prefix                              = var.cluster_prefix
  enable_ldap                         = var.enable_ldap
  ldap_server                         = local.ldap_server != "null" ? local.ldap_server : join(",", local.ldap_hosts)
  playbooks_path                      = local.playbooks_path
  ldap_basedns                        = var.ldap_basedns
  ldap_admin_password                 = local.ldap_admin_password
  ldap_user_name                      = var.ldap_user_name
  ldap_user_password                  = var.ldap_user_password
  ldap_server_cert                    = local.ldap_server_cert
  nfs_shares_map                      = local.nfs_shares_map
  depends_on                          = [module.write_compute_cluster_inventory]
}

module "ldap_inventory" {
  count               = var.enable_deployer == false && var.scheduler == "LSF" && var.enable_ldap && local.ldap_server == "null" ? 1 : 0
  source              = "./modules/inventory"
  prefix              = var.cluster_prefix
  name_mount_path_map = local.fileshare_name_mount_path_map
  enable_ldap         = var.enable_ldap
  ldap_server         = local.ldap_server != "null" ? local.ldap_server : join(",", local.ldap_hosts)
  playbooks_path      = local.playbooks_path
  ldap_basedns        = var.ldap_basedns
  ldap_admin_password = local.ldap_admin_password
  ldap_user_name      = var.ldap_user_name
  ldap_user_password  = var.ldap_user_password
  ldap_server_cert    = local.ldap_server_cert
  depends_on          = [module.write_compute_cluster_inventory]
}

module "mgmt_inventory_hosts" {
  count          = var.enable_deployer == false && var.scheduler == "LSF" ? 1 : 0
  source         = "./modules/inventory_hosts"
  hosts          = local.mgmt_hosts_ips
  inventory_path = local.mgmt_hosts_inventory_path
}

module "compute_inventory_hosts" {
  count          = var.enable_deployer == false ? 1 : 0
  source         = "./modules/inventory_hosts"
  hosts          = var.scheduler == "Scale" ? local.all_compute_hosts : local.compute_hosts_ips
  inventory_path = local.compute_hosts_inventory_path
}

module "login_inventory_host" {
  count          = var.enable_deployer == false && var.scheduler == "LSF" ? 1 : 0
  source         = "./modules/inventory_hosts"
  hosts          = local.login_host_ip
  inventory_path = local.login_host_inventory_path
}

module "bastion_inventory_hosts" {
  count          = var.enable_deployer == true ? 1 : 0
  source         = "./modules/inventory_hosts"
  hosts          = local.bastion_hosts_ips
  inventory_path = local.bastion_hosts_inventory_path
}

module "deployer_inventory_hosts" {
  count          = var.enable_deployer == true ? 1 : 0
  source         = "./modules/inventory_hosts"
  hosts          = local.deployer_hosts_ips
  inventory_path = local.deployer_hosts_inventory_path
}

module "ldap_inventory_hosts" {
  count          = var.enable_deployer == false && var.enable_ldap == true ? 1 : 0
  source         = "./modules/inventory_hosts"
  hosts          = local.ldap_hosts
  inventory_path = local.ldap_hosts_inventory_path
}

module "client_inventory_hosts" {
  count          = var.enable_deployer == false && var.scheduler == "Scale" ? 1 : 0
  source         = "./modules/inventory_hosts"
  hosts          = local.client_hosts
  inventory_path = local.client_hosts_inventory_path
}

module "protocol_inventory_hosts" {
  count          = var.enable_deployer == false && var.scheduler == "Scale" ? 1 : 0
  source         = "./modules/inventory_hosts"
  hosts          = local.protocol_hosts
  inventory_path = local.protocol_hosts_inventory_path
}

module "afm_inventory_hosts" {
  count          = var.enable_deployer == false && var.scheduler == "Scale" ? 1 : 0
  source         = "./modules/inventory_hosts"
  hosts          = local.afm_hosts
  inventory_path = local.afm_hosts_inventory_path
}

module "gklm_inventory_hosts" {
  count          = var.enable_deployer == false && var.scheduler == "Scale" ? 1 : 0
  source         = "./modules/inventory_hosts"
  hosts          = local.gklm_hosts
  inventory_path = local.gklm_hosts_inventory_path
}

module "storage_inventory_hosts" {
  count          = var.enable_deployer == false && var.scheduler == "Scale" ? 1 : 0
  source         = "./modules/inventory_hosts"
  hosts          = local.all_storage_hosts
  inventory_path = local.storage_hosts_inventory_path
}

module "post_cluster_setup" {
  count                = var.scheduler == "Scale" && var.enable_deployer == false ? 1 : 0
  turn_on              = var.create_separate_namespaces
  source               = "./modules/post_cluster_setup"
  create_scale_cluster = var.create_scale_cluster
  storage_turn_on      = (var.create_separate_namespaces == true && local.storage_instance_count > 0) ? true : false
  compute_turn_on      = (var.create_separate_namespaces == true && local.static_compute_instance_count > 0) ? true : false
  clone_path           = var.scale_ansible_repo_clone_path
  depends_on           = [module.compute_cluster_configuration, module.storage_cluster_configuration, module.remote_mount_configuration, module.encryption_configuration, module.invoke_compute_network_playbook, module.invoke_storage_network_playbook]
}

module "compute_playbook" {
  count                       = var.enable_deployer == false ? 1 : 0
  source                      = "./modules/playbook"
  scheduler                   = var.scheduler
  bastion_fip                 = local.bastion_fip
  private_key_path            = local.compute_private_key_path
  inventory_path              = local.compute_inventory_path
  enable_deployer             = var.enable_deployer
  ibmcloud_api_key            = var.ibmcloud_api_key
  observability_provision     = var.observability_logs_enable_for_management || var.observability_logs_enable_for_compute || var.observability_monitoring_enable ? true : false
  cloudlogs_provision         = var.observability_logs_enable_for_management || var.observability_logs_enable_for_compute ? true : false
  observability_playbook_path = local.observability_playbook_path
  lsf_mgmt_playbooks_path     = local.lsf_mgmt_playbooks_path
  enable_ldap                 = var.enable_ldap
  ldap_server                 = local.ldap_server
  playbooks_path              = local.playbooks_path
  mgmnt_hosts                 = local.mgmnt_host_entry
  comp_hosts                  = local.comp_host_entry
  login_host                  = local.login_host_entry
  deployer_host               = local.deployer_host_entry
  domain_name                 = var.dns_domain_names["compute"]
  enable_dedicated_host       = var.enable_dedicated_host
  depends_on                  = [module.compute_inventory, module.landing_zone_vsi]
}

###################################################
# Observability Modules
###################################################

module "cloud_monitoring_instance_creation" {
  count                          = var.enable_deployer == false ? 1 : 0
  source                         = "./modules/observability_instance"
  location                       = local.region
  rg                             = var.resource_group_ids["service_rg"]
  cloud_monitoring_provision     = var.observability_monitoring_enable
  observability_monitoring_plan  = var.observability_monitoring_plan
  enable_metrics_routing         = var.observability_enable_metrics_routing
  enable_platform_logs           = var.observability_enable_platform_logs
  cluster_prefix                 = var.cluster_prefix
  cloud_monitoring_instance_name = "${var.cluster_prefix}-metrics"
  cloud_logs_provision           = var.observability_logs_enable_for_management || var.observability_logs_enable_for_compute ? true : false
  cloud_logs_instance_name       = "${var.cluster_prefix}-cloud-logs"
  cloud_logs_retention_period    = var.observability_logs_retention_period
  cloud_logs_as_atracker_target  = var.observability_atracker_enable && (var.observability_atracker_target_type == "cloudlogs") ? true : false
  cloud_logs_data_bucket         = var.cloud_logs_data_bucket
  cloud_metrics_data_bucket      = var.cloud_metrics_data_bucket
  tags                           = [local.scheduler_lowercase, var.cluster_prefix]
}

# Code for SCC Instance
module "scc_workload_protection" {
  source                                       = "./modules/security/sccwp"
  resource_group_name                          = var.existing_resource_group != "null" ? var.existing_resource_group : "${var.cluster_prefix}-service-rg"
  prefix                                       = var.cluster_prefix
  region                                       = local.region
  sccwp_service_plan                           = var.sccwp_service_plan
  resource_tags                                = [local.scheduler_lowercase, var.cluster_prefix]
  enable_deployer                              = var.enable_deployer
  sccwp_enable                                 = var.sccwp_enable
  cspm_enabled                                 = var.cspm_enabled
  app_config_plan                              = var.app_config_plan
  scc_workload_protection_trusted_profile_name = "${var.cluster_prefix}-wp-tp"
}
