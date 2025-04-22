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
  storage_servers            = var.storage_type == "persistent" ? var.storage_servers : [] 
  protocol_subnets           = local.protocol_subnets
  protocol_instances         = var.protocol_instances
  nsd_details                = var.nsd_details
  dns_domain_names           = var.dns_domain_names
  kms_encryption_enabled     = local.kms_encryption_enabled
  boot_volume_encryption_key = local.boot_volume_encryption_key
  enable_bastion             = var.enable_bastion
  afm_instances              = var.afm_instances
  enable_ldap                = var.enable_ldap
  ldap_instances             = var.ldap_instances
  ldap_server                = var.ldap_server
  ldap_instance_key_pair     = local.ldap_instance_key_pair
  scale_encryption_enabled   = var.scale_encryption_enabled
  scale_encryption_type      = var.scale_encryption_type
  gklm_instance_key_pair     = local.gklm_instance_key_pair
  gklm_instances             = var.gklm_instances
  vpc_region                 = local.region
  scheduler                  = var.scheduler
}

module "prepare_tf_input" {
  source                                           = "./modules/prepare_tf_input"
  scheduler                                        = var.scheduler
  enable_deployer                                  = var.enable_deployer
  deployer_ip                                      = local.deployer_ip
  ibmcloud_api_key                                 = var.ibmcloud_api_key
  existing_resource_group                          = var.existing_resource_group
  prefix                                           = var.prefix
  zones                                            = var.zones
  compute_ssh_keys                                 = local.compute_ssh_keys
  storage_ssh_keys                                 = local.storage_ssh_keys
  storage_instances                                = var.storage_type == "scratch" ? var.storage_instances : []
  storage_servers                                  = var.storage_type == "persistent" ? var.storage_servers : []
  management_instances                             = var.management_instances
  protocol_instances                               = var.protocol_instances
  colocate_protocol_cluster_instances              = var.colocate_protocol_cluster_instances
  ibm_customer_number                              = var.ibm_customer_number
  static_compute_instances                         = var.static_compute_instances
  dynamic_compute_instances                        = var.dynamic_compute_instances
  client_instances                                 = var.client_instances
  enable_cos_integration                           = var.enable_cos_integration
  enable_atracker                                  = var.enable_atracker
  enable_vpc_flow_logs                             = var.enable_vpc_flow_logs
  allowed_cidr                                     = var.allowed_cidr
  vpc_name                                         = local.vpc_name
  storage_subnets                                  = local.storage_subnet
  protocol_subnets                                 = local.protocol_subnet
  compute_subnets                                  = local.compute_subnet
  client_subnets                                   = local.client_subnet
  bastion_subnets                                  = local.bastion_subnet
  dns_domain_names                                 = var.dns_domain_names
  bastion_security_group_id                        = local.bastion_security_group_id
  deployer_hostname                                = local.deployer_hostname
  enable_hyperthreading                            = var.enable_hyperthreading
  scc_enable                                       = var.scc_enable
  scc_profile                                      = var.scc_profile
  scc_location                                     = var.scc_location
  scc_cos_bucket                                   = local.scc_cos_bucket
  scc_cos_instance_crn                             = local.scc_cos_instance_crn
  scc_event_notification_plan                      = var.scc_event_notification_plan
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
  ldap_instances                                   = var.ldap_instances
  ldap_server                                      = var.ldap_server
  ldap_basedns                                     = var.ldap_basedns
  ldap_server_cert                                 = var.ldap_server_cert
  ldap_admin_password                              = var.ldap_admin_password
  ldap_instance_key_pair                           = local.ldap_instance_key_pair
  ldap_user_password                               = var.ldap_user_password
  ldap_user_name                                   = var.ldap_user_name
  afm_instances                                    = var.afm_instances
  afm_cos_config                                   = var.afm_cos_config
  gklm_instance_key_pair                           = local.gklm_instance_key_pair
  gklm_instances                                   = var.gklm_instances
  scale_encryption_type                            = var.scale_encryption_type
  filesystem_config                                = var.filesystem_config
  scale_encryption_admin_password                  = var.scale_encryption_admin_password
  scale_encryption_enabled                         = var.scale_encryption_enabled
  depends_on                                       = [module.deployer]
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

module "cos" {
  count                           = var.scheduler == "null" && local.enable_afm == true ? 1 : 0
  source                          = "./modules/cos"
  prefix                          = "${var.prefix}-"
  resource_group_id               = local.resource_group_ids["service_rg"]
  cos_instance_plan               = "standard"
  cos_instance_location           = "global"
  cos_instance_service            = "cloud-object-storage"
  cos_hmac_role                   = "Manager"
  new_instance_bucket_hmac        = local.new_instance_bucket_hmac
  exstng_instance_new_bucket_hmac = local.exstng_instance_new_bucket_hmac
  exstng_instance_bucket_new_hmac = local.exstng_instance_bucket_new_hmac
  exstng_instance_hmac_new_bucket = local.exstng_instance_hmac_new_bucket
  exstng_instance_bucket_hmac     = local.exstng_instance_bucket_hmac
  filesystem                      = local.resolved_filesystem
  depends_on                      = [module.landing_zone_vsi]
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

module "protocol_reserved_ip" {
  count                   = var.scheduler == "null" && var.enable_deployer == false ? 1 : 0
  source                  = "./modules/protocol_reserved_ip"
  total_reserved_ips      = local.protocol_instance_count
  subnet_id               = [local.protocol_subnets[0].id]
  name                    = format("%s-ces", var.prefix)
  protocol_domain         = var.dns_domain_names["protocol"]
  protocol_dns_service_id = local.dns_instance_id
  protocol_dns_zone_id    = local.protocol_dns_zone_id
  depends_on              = [module.dns]
}

module "client_dns_records" {
  count           = var.enable_deployer == false ? 1 : 0
  source          = "./modules/dns_record"
  dns_instance_id = local.dns_instance_id
  dns_zone_id     = local.client_dns_zone_id
  dns_records     = local.client_dns_records
  depends_on      = [module.dns]
}

module "gklm_dns_records" {
  count           = var.enable_deployer == false ? 1 : 0
  source          = "./modules/dns_record"
  dns_instance_id = local.dns_instance_id
  dns_zone_id     = local.gklm_dns_zone_id
  dns_records     = local.gklm_dns_records
  depends_on      = [module.dns]
}

resource "time_sleep" "wait_60_seconds" {
  create_duration = "60s"
  depends_on      = [module.storage_dns_records, module.protocol_reserved_ip, module.compute_dns_records]
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
  my_cluster_name             = var.prefix
  ha_shared_dir               = local.ha_shared_dir
  nfs_install_dir             = local.nfs_install_dir
  enable_monitoring           = local.enable_monitoring
  lsf_deployer_hostname       = local.lsf_deployer_hostname
  ibmcloud_api_key            = var.ibmcloud_api_key
  dns_domain_names            = var.dns_domain_names
  compute_public_key_content  = local.compute_public_key_content
  compute_private_key_content = local.compute_private_key_content
  enable_hyperthreading       = var.enable_hyperthreading
  compute_subnet_id           = local.compute_subnet_id
  region                      = local.region
  resource_group_id           = local.resource_group_ids["service_rg"]
  zones                       = var.zones
  vpc_id                      = local.vpc_id
  compute_subnets_cidr        = var.compute_subnets_cidr
  dynamic_compute_instances   = var.dynamic_compute_instances
  compute_security_group_id   = local.compute_security_group_id
  compute_ssh_keys_ids        = local.compute_ssh_keys_ids
  compute_subnet_crn          = local.compute_subnet_crn
  depends_on                  = [time_sleep.wait_60_seconds]
}

module "write_compute_scale_cluster_inventory" {
  count                                            = var.scheduler == "null" && var.enable_deployer == false ? 1 : 0
  source                                           = "./modules/write_scale_inventory"
  json_inventory_path                              = var.scheduler == "null" ? format("%s/compute_cluster_inventory.json", var.scale_ansible_repo_clone_path) : format("%s/compute_cluster_inventory.json", local.json_inventory_path)
  bastion_user                                     = jsonencode(var.bastion_user)
  bastion_instance_id                              = var.bastion_instance_id == null ? jsonencode("None") : jsonencode(var.bastion_instance_id)
  bastion_instance_public_ip                       = var.bastion_fip == null ? jsonencode("None") : jsonencode(var.bastion_fip)
  cloud_platform                                   = jsonencode("IBMCloud")
  resource_prefix                                  = jsonencode(format("%s.%s", var.prefix, var.dns_domain_names["compute"]))
  vpc_region                                       = jsonencode(local.region)
  vpc_availability_zones                           = jsonencode(var.zones)
  scale_version                                    = jsonencode(local.scale_version)
  compute_cluster_filesystem_mountpoint            = jsonencode(var.static_compute_instances[0]["filesystem"])
  storage_cluster_filesystem_mountpoint            = jsonencode("None")
  filesystem_block_size                            = jsonencode("None")
  compute_cluster_instance_private_ips             = jsonencode(concat((local.enable_sec_interface_compute ? local.secondary_compute_instance_private_ips : local.compute_instance_private_ips), local.compute_mgmt_instance_private_ips))
  compute_cluster_instance_ids                     = jsonencode(concat((local.enable_sec_interface_compute ? local.secondary_compute_instance_private_ips : local.compute_instance_ids), local.compute_mgmt_instance_ids))
  compute_cluster_instance_names                   = jsonencode(concat((local.enable_sec_interface_compute ? local.secondary_compute_instance_private_ips : local.compute_instance_names), local.compute_mgmt_instance_names))
  compute_cluster_instance_private_dns_ip_map      = jsonencode({})
  storage_cluster_instance_ids                     = jsonencode([])
  storage_cluster_instance_private_ips             = jsonencode([])
  storage_cluster_with_data_volume_mapping         = jsonencode({})
  storage_cluster_instance_private_dns_ip_map      = jsonencode({})
  storage_cluster_desc_instance_ids                = jsonencode([])
  storage_cluster_desc_instance_private_ips        = jsonencode([])
  storage_cluster_desc_data_volume_mapping         = jsonencode({})
  storage_cluster_desc_instance_private_dns_ip_map = jsonencode({})
  storage_cluster_instance_names                   = jsonencode([])
  storage_subnet_cidr                              = local.enable_mrot_conf ? jsonencode(data.ibm_is_subnet.existing_storage_subnets[*].ipv4_cidr_block) : jsonencode("")
  compute_subnet_cidr                              = local.enable_mrot_conf ? jsonencode(data.ibm_is_subnet.existing_compute_subnets[*].ipv4_cidr_block) : jsonencode("")
  scale_remote_cluster_clustername                 = local.enable_mrot_conf ? jsonencode(format("%s.%s", var.prefix, var.prefix, var.dns_domain_names["storage"])) : jsonencode("")
  protocol_cluster_instance_names                  = jsonencode([])
  client_cluster_instance_names                    = jsonencode([])
  protocol_cluster_reserved_names                  = jsonencode([])
  smb                                              = false
  nfs                                              = true
  object                                           = false
  interface                                        = jsonencode([])
  export_ip_pool                                   = jsonencode([])
  filesystem                                       = jsonencode("")
  mountpoint                                       = jsonencode("")
  protocol_gateway_ip                              = jsonencode("")
  filesets                                         = jsonencode({})
  afm_cos_bucket_details                           = jsonencode([])
  afm_config_details                               = jsonencode([])
  afm_cluster_instance_names                       = jsonencode([])
  filesystem_mountpoint                            = var.scale_encryption_type == "key_protect" ? jsonencode(local.resolved_filesystem) : jsonencode("")
  depends_on                                       = [time_sleep.wait_60_seconds]
}

module "write_storage_scale_cluster_inventory" {
  count                                            = var.scheduler == "null" && var.enable_deployer == false ? 1 : 0
  source                                           = "./modules/write_scale_inventory"
  json_inventory_path                              = format("%s/storage_cluster_inventory.json", var.scale_ansible_repo_clone_path)
  bastion_user                                     = jsonencode(var.bastion_user)
  bastion_instance_id                              = var.bastion_instance_id == null ? jsonencode("None") : jsonencode(var.bastion_instance_id)
  bastion_instance_public_ip                       = var.bastion_fip == null ? jsonencode("None") : jsonencode(var.bastion_fip)
  cloud_platform                                   = jsonencode("IBMCloud")
  resource_prefix                                  = jsonencode(format("%s.%s", var.prefix, var.dns_domain_names["storage"]))
  vpc_region                                       = jsonencode(local.region)
  vpc_availability_zones                           = jsonencode(var.zones)
  scale_version                                    = jsonencode(local.scale_version)
  compute_cluster_filesystem_mountpoint            = jsonencode("None")
  storage_cluster_filesystem_mountpoint            = jsonencode(var.filesystem_config[0]["mount_point"]) #jsonencode(var.storage_instances[count.index].filesystem)
  filesystem_block_size                            = jsonencode(var.filesystem_config[0]["block_size"])
  compute_cluster_instance_ids                     = jsonencode([])
  compute_cluster_instance_private_ips             = jsonencode([])
  compute_cluster_instance_private_dns_ip_map      = jsonencode({})
  compute_cluster_instance_names                   = jsonencode([])
  storage_cluster_instance_ids                     = var.storage_type == "persistent" ? jsonencode(concat(local.baremetal_cluster_instance_ids, local.strg_mgmtt_instance_ids, local.tie_breaker_storage_instance_ids)) : jsonencode(concat(local.storage_cluster_instance_ids, local.strg_mgmtt_instance_ids, local.tie_breaker_storage_instance_ids))
  storage_cluster_instance_private_ips             = var.storage_type == "persistent" ? jsonencode(concat(local.baremetal_cluster_instance_private_ips, local.strg_mgmt_instance_private_ips, local.tie_breaker_storage_instance_private_ips)) : jsonencode(concat(local.storage_cluster_instance_private_ips, local.strg_mgmt_instance_private_ips, local.tie_breaker_storage_instance_private_ips))
  storage_cluster_instance_names                   = var.storage_type == "persistent" ? jsonencode(concat(local.baremetal_cluster_instance_names, local.strg_mgmt_instance_names, local.tie_breaker_storage_instance_names)) : jsonencode(concat(local.storage_cluster_instance_names, local.strg_mgmt_instance_names, local.tie_breaker_storage_instance_names))
  storage_cluster_with_data_volume_mapping         = jsonencode(local.storage_ips_with_vol_mapping[0])
  storage_cluster_instance_private_dns_ip_map      = jsonencode({})
  storage_cluster_desc_instance_private_ips        = jsonencode(local.strg_tie_breaker_private_ips)
  storage_cluster_desc_instance_ids                = jsonencode(local.strg_tie_breaker_instance_ids)
  storage_cluster_desc_data_volume_mapping         = jsonencode(local.tie_breaker_ips_with_vol_mapping[0])
  storage_cluster_desc_instance_private_dns_ip_map = jsonencode({})
  storage_subnet_cidr                              = local.enable_mrot_conf ? jsonencode(data.ibm_is_subnet.existing_storage_subnets[*].ipv4_cidr_block) : jsonencode("")
  compute_subnet_cidr                              = local.enable_mrot_conf || local.scale_ces_enabled == true ? jsonencode(data.ibm_is_subnet.existing_compute_subnets[*].ipv4_cidr_block) : jsonencode("")
  scale_remote_cluster_clustername                 = local.enable_mrot_conf ? jsonencode(format("%s.%s", var.prefix, var.dns_domain_names["compute"])) : jsonencode("")
  protocol_cluster_instance_names                  = local.scale_ces_enabled == true ? jsonencode(local.protocol_instance_names) : jsonencode([])
  client_cluster_instance_names                    = jsonencode([])
  protocol_cluster_reserved_names                  = jsonencode([])
  smb                                              = false
  nfs                                              = local.scale_ces_enabled == true ? true : false
  object                                           = false
  interface                                        = jsonencode([])
  export_ip_pool                                   = local.scale_ces_enabled == true ? jsonencode(values(one(module.protocol_reserved_ip[*].instance_name_ip_map))) : jsonencode([])
  filesystem                                       = local.scale_ces_enabled == true ? jsonencode("cesSharedRoot") : jsonencode("")
  mountpoint                                       = local.scale_ces_enabled == true ? jsonencode(var.filesystem_config[0]["mount_point"]) : jsonencode("")
  protocol_gateway_ip                              = jsonencode("")
  filesets                                         = jsonencode(local.fileset_size_map)
  afm_cos_bucket_details                           = local.enable_afm == true ? jsonencode(local.afm_cos_bucket_details) : jsonencode([])
  afm_config_details                               = local.enable_afm == true ? jsonencode(local.afm_cos_config) : jsonencode([])
  afm_cluster_instance_names                       = jsonencode(local.afm_instance_names)
  filesystem_mountpoint                            = var.scale_encryption_type == "key_protect" ? (var.storage_instances[*]["filesystem"] != "" ? var.storage_instances[*]["filesystem"] : jsonencode(var.filesystem_config[0]["filesystem"])) : jsonencode("")
  depends_on                                       = [time_sleep.wait_60_seconds]
}

module "write_client_scale_cluster_inventory" {
  count                                            = var.scheduler == "null" && var.enable_deployer == false ? 1 : 0
  source                                           = "./modules/write_scale_inventory"
  json_inventory_path                              = format("%s/client_cluster_inventory.json", var.scale_ansible_repo_clone_path)
  bastion_user                                     = jsonencode(var.bastion_user)
  bastion_instance_id                              = var.bastion_instance_id == null ? jsonencode("None") : jsonencode(var.bastion_instance_id)
  bastion_instance_public_ip                       = var.bastion_fip == null ? jsonencode("None") : jsonencode(var.bastion_fip)
  cloud_platform                                   = jsonencode("")
  resource_prefix                                  = jsonencode("")
  vpc_region                                       = jsonencode("")
  vpc_availability_zones                           = jsonencode([])
  scale_version                                    = jsonencode("")
  filesystem_block_size                            = jsonencode("")
  compute_cluster_filesystem_mountpoint            = jsonencode("None")
  compute_cluster_instance_ids                     = jsonencode("")
  compute_cluster_instance_private_ips             = jsonencode("")
  compute_cluster_instance_private_dns_ip_map      = jsonencode({})
  storage_cluster_filesystem_mountpoint            = local.scale_ces_enabled == true ? jsonencode(var.filesystem_config[0]["mount_point"]) : jsonencode("")
  storage_cluster_instance_ids                     = jsonencode([])
  storage_cluster_instance_private_ips             = jsonencode([])
  storage_cluster_with_data_volume_mapping         = jsonencode({})
  storage_cluster_instance_private_dns_ip_map      = jsonencode({})
  storage_cluster_desc_instance_ids                = jsonencode([])
  storage_cluster_desc_instance_private_ips        = jsonencode([])
  storage_cluster_desc_data_volume_mapping         = jsonencode({})
  storage_cluster_desc_instance_private_dns_ip_map = jsonencode({})
  storage_cluster_instance_names                   = jsonencode([])
  compute_cluster_instance_names                   = jsonencode([])
  storage_subnet_cidr                              = jsonencode("")
  compute_subnet_cidr                              = jsonencode("")
  scale_remote_cluster_clustername                 = jsonencode("")
  protocol_cluster_instance_names                  = jsonencode([])
  client_cluster_instance_names                    = local.scale_ces_enabled == true ? jsonencode(local.client_instance_names) : jsonencode([])
  protocol_cluster_reserved_names                  = local.scale_ces_enabled == true ? jsonencode(format("%s-ces.%s", var.prefix, var.dns_domain_names["protocol"])) : jsonencode([])
  smb                                              = false
  nfs                                              = false
  object                                           = false
  interface                                        = jsonencode([])
  export_ip_pool                                   = jsonencode([])
  filesystem                                       = jsonencode("")
  mountpoint                                       = jsonencode("")
  protocol_gateway_ip                              = jsonencode("")
  filesets                                         = local.scale_ces_enabled == true ? jsonencode(local.fileset_size_map) : jsonencode({})
  afm_cos_bucket_details                           = jsonencode([])
  afm_config_details                               = jsonencode([])
  afm_cluster_instance_names                       = jsonencode([])
  filesystem_mountpoint                            = jsonencode("")
}

module "compute_cluster_configuration" {
  count                           = var.scheduler == "null" && var.enable_deployer == false ? 1 : 0
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
  comp_memory                     = data.ibm_is_instance_profile.compute_profile.memory[0].value
  comp_vcpus_count                = data.ibm_is_instance_profile.compute_profile.vcpu_count[0].value
  comp_bandwidth                  = data.ibm_is_instance_profile.compute_profile.bandwidth[0].value
  bastion_instance_public_ip      = jsonencode(local.bastion_fip)
  bastion_ssh_private_key         = var.bastion_ssh_private_key
  meta_private_key                = module.landing_zone_vsi[0].compute_private_key_content
  scale_version                   = local.scale_version
  spectrumscale_rpms_path         = var.spectrumscale_rpms_path
  enable_mrot_conf                = local.enable_mrot_conf ? "True" : "False"
  enable_ces                      = "False"
  enable_afm                      = "False"
  scale_encryption_enabled        = var.scale_encryption_enabled
  scale_encryption_admin_password = var.scale_encryption_admin_password
  scale_encryption_servers        = var.scale_encryption_enabled && var.scale_encryption_type == "gklm" ? jsonencode(local.gklm_instance_private_ips) : null
  enable_ldap                     = var.enable_ldap
  ldap_basedns                    = var.ldap_basedns
  ldap_server                     = var.enable_ldap ? local.ldap_instance_private_ips[0] : jsonencode("")
  ldap_admin_password             = var.ldap_admin_password
  enable_key_protect              = var.scale_encryption_type == "key_protect" ? "True" : "False"
  depends_on                      = [module.write_compute_scale_cluster_inventory]
}

module "storage_cluster_configuration" {
  count                               = var.scheduler == "null" && var.enable_deployer == false ? 1 : 0
  source                              = "./modules/common/storage_configuration"
  turn_on                             = (var.create_separate_namespaces == true && local.storage_instance_count > 0) ? true : false
  bastion_user                        = jsonencode(var.bastion_user)
  write_inventory_complete            = module.write_storage_scale_cluster_inventory[0].write_scale_inventory_complete
  inventory_format                    = var.inventory_format
  create_scale_cluster                = var.create_scale_cluster
  clone_path                          = var.scale_ansible_repo_clone_path
  inventory_path                      = format("%s/storage_cluster_inventory.json", var.scale_ansible_repo_clone_path)
  using_packer_image                  = var.using_packer_image
  using_jumphost_connection           = var.using_jumphost_connection
  using_rest_initialization           = true
  storage_cluster_gui_username        = var.storage_gui_username
  storage_cluster_gui_password        = var.storage_gui_password
  colocate_protocol_cluster_instances = var.colocate_protocol_cluster_instances == true ? "True" : "False"
  is_colocate_protocol_subset         = local.is_colocate_protocol_subset == true ? "True" : "False"
  mgmt_memory                         = data.ibm_is_instance_profile.management_profile.memory[0].value
  mgmt_vcpus_count                    = data.ibm_is_instance_profile.management_profile.vcpu_count[0].value
  mgmt_bandwidth                      = data.ibm_is_instance_profile.management_profile.bandwidth[0].value
  strg_desc_memory                    = data.ibm_is_instance_profile.storage_profile.memory[0].value
  strg_desc_vcpus_count               = data.ibm_is_instance_profile.storage_profile.vcpu_count[0].value
  strg_desc_bandwidth                 = data.ibm_is_instance_profile.storage_profile.bandwidth[0].value
  strg_memory                         = var.storage_type == "persistent" ? jsonencode("") : data.ibm_is_instance_profile.storage_profile.memory[0].value
  strg_vcpus_count                    = var.storage_type == "persistent" ? jsonencode("") : data.ibm_is_instance_profile.storage_profile.vcpu_count[0].value
  strg_bandwidth                      = var.storage_type == "persistent" ? jsonencode("") : data.ibm_is_instance_profile.storage_profile.bandwidth[0].value
  proto_memory                        = (local.scale_ces_enabled == true && var.colocate_protocol_cluster_instances == false) ? local.ces_server_type == false ? data.ibm_is_instance_profile.protocol_profile[0].memory[0].value : jsonencode(0) : jsonencode(0)
  proto_vcpus_count                   = (local.scale_ces_enabled == true && var.colocate_protocol_cluster_instances == false) ? local.ces_server_type == false ? data.ibm_is_instance_profile.protocol_profile[0].vcpu_count[0].value : jsonencode(0) : jsonencode(0)
  proto_bandwidth                     = (local.scale_ces_enabled == true && var.colocate_protocol_cluster_instances == false) ? local.ces_server_type == false ? data.ibm_is_instance_profile.protocol_profile[0].bandwidth[0].value : jsonencode(0) : jsonencode(0)
  strg_proto_memory                   = var.storage_type == "persistent" ? jsonencode("") : data.ibm_is_instance_profile.storage_profile.memory[0].value
  strg_proto_vcpus_count              = var.storage_type == "persistent" ? jsonencode("") : data.ibm_is_instance_profile.storage_profile.vcpu_count[0].value
  strg_proto_bandwidth                = var.storage_type == "persistent" ? jsonencode("") : data.ibm_is_instance_profile.storage_profile.bandwidth[0].value
  afm_memory                          = local.afm_server_type == true ? jsonencode("") : data.ibm_is_instance_profile.afm_server_profile[0].memory[0].value
  afm_vcpus_count                     = local.afm_server_type == true ? jsonencode("") : data.ibm_is_instance_profile.afm_server_profile[0].vcpu_count[0].value
  afm_bandwidth                       = local.afm_server_type == true ? jsonencode("") : data.ibm_is_instance_profile.afm_server_profile[0].bandwidth[0].value
  disk_type                           = "network-attached"
  max_data_replicas                   = var.filesystem_config[0]["max_data_replica"]
  max_metadata_replicas               = var.filesystem_config[0]["max_metadata_replica"]
  default_metadata_replicas           = var.filesystem_config[0]["default_metadata_replica"]
  default_data_replicas               = var.filesystem_config[0]["default_data_replica"]
  bastion_instance_public_ip          = jsonencode(local.bastion_fip)
  bastion_ssh_private_key             = var.bastion_ssh_private_key
  meta_private_key                    = module.landing_zone_vsi[0].storage_private_key_content
  scale_version                       = local.scale_version
  spectrumscale_rpms_path             = var.spectrumscale_rpms_path
  enable_mrot_conf                    = local.enable_mrot_conf ? "True" : "False"
  enable_ces                          = local.scale_ces_enabled == true ? "True" : "False"
  enable_afm                          = local.enable_afm == true ? "True" : "False"
  scale_encryption_enabled            = var.scale_encryption_enabled
  scale_encryption_type               = var.scale_encryption_type != null ? var.scale_encryption_type : null
  scale_encryption_admin_password     = var.scale_encryption_admin_password
  scale_encryption_servers            = var.scale_encryption_enabled && var.scale_encryption_type == "gklm" ? jsonencode(local.gklm_instance_private_ips) : null
  enable_ldap                         = var.enable_ldap
  ldap_basedns                        = var.ldap_basedns
  ldap_server                         = var.enable_ldap ? local.ldap_instance_private_ips[0] : jsonencode("")
  ldap_admin_password                 = var.ldap_admin_password
  ldap_server_cert                    = var.ldap_server_cert
  enable_key_protect                  = var.scale_encryption_type == "key_protect" ? "True" : "False"
  depends_on                          = [module.write_storage_scale_cluster_inventory]
}

module "remote_mount_configuration" {
  count                           = var.scheduler == "null" && var.enable_deployer == false ? 1 : 0
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

# module "write_storage_cluster_inventory" {
#   count                 = var.enable_deployer == false ? 1 : 0
#   source                = "./modules/write_inventory"
#   json_inventory_path   = local.json_inventory_path
#   lsf_masters           = local.management_nodes
#   lsf_servers           = local.compute_nodes_list
#   lsf_clients           = local.client_nodes
#   gui_hosts             = local.gui_hosts
#   db_hosts              = local.db_hosts
#   my_cluster_name       = var.prefix
#   ha_shared_dir         = local.ha_shared_dir
#   nfs_install_dir       = local.nfs_install_dir
#   enable_monitoring     = local.enable_monitoring
#   lsf_deployer_hostname = local.lsf_deployer_hostname
#   depends_on            = [time_sleep.wait_60_seconds]
# }

module "compute_inventory" {
  count                               = var.enable_deployer == false ? 1 : 0
  source                              = "./modules/inventory"
  scheduler                           = var.scheduler
  hosts                               = local.compute_hosts
  inventory_path                      = local.compute_inventory_path
  name_mount_path_map                 = local.fileshare_name_mount_path_map
  logs_enable_for_management          = var.observability_logs_enable_for_management
  monitoring_enable_for_management    = var.observability_monitoring_enable
  monitoring_enable_for_compute       = var.observability_monitoring_on_compute_nodes_enable
  cloud_monitoring_access_key         = var.observability_monitoring_enable ? module.cloud_monitoring_instance_creation.cloud_monitoring_access_key : ""
  cloud_monitoring_ingestion_url      = var.observability_monitoring_enable ? module.cloud_monitoring_instance_creation.cloud_monitoring_ingestion_url : ""
  cloud_monitoring_prws_key           = var.observability_monitoring_enable ? module.cloud_monitoring_instance_creation.cloud_monitoring_prws_key : ""
  cloud_monitoring_prws_url           = var.observability_monitoring_enable ? module.cloud_monitoring_instance_creation.cloud_monitoring_prws_url : ""
  logs_enable_for_compute             = var.observability_logs_enable_for_compute
  cloud_logs_ingress_private_endpoint = local.cloud_logs_ingress_private_endpoint
  depends_on                          = [module.write_compute_cluster_inventory]
}

# module "storage_inventory" {
#   count               = var.enable_deployer == false ? 1 : 0
#   source              = "./modules/inventory"
#   hosts               = local.storage_hosts
#   inventory_path      = local.storage_inventory_path
#   name_mount_path_map = local.fileshare_name_mount_path_map
#   depends_on          = [module.write_storage_cluster_inventory]
# }

module "compute_playbook" {
  count                       = var.enable_deployer == false ? 1 : 0
  source                      = "./modules/playbook"
  scheduler                   = var.scheduler
  bastion_fip                 = local.bastion_fip
  private_key_path            = local.compute_private_key_path
  inventory_path              = local.compute_inventory_path
  playbook_path               = local.compute_playbook_path
  enable_bastion              = var.enable_bastion
  ibmcloud_api_key            = var.ibmcloud_api_key
  observability_provision     = var.observability_logs_enable_for_management || var.observability_logs_enable_for_compute || var.observability_monitoring_enable ? true : false
  cloudlogs_provision         = var.observability_logs_enable_for_management || var.observability_logs_enable_for_compute ? true : false
  observability_playbook_path = local.observability_playbook_path
  playbooks_root_path         = local.playbooks_root_path
  depends_on                  = [module.compute_inventory]
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
  cloud_logs_data_bucket         = var.cloud_logs_data_bucket
  cloud_metrics_data_bucket      = var.cloud_metrics_data_bucket
  tags                           = ["hpc", var.prefix]
}

# Code for SCC Instance
module "scc_instance_and_profile" {
  count                   = var.enable_deployer == false && var.scc_enable ? 1 : 0
  source                  = "./modules/security/scc"
  location                = var.scc_location != "" ? var.scc_location : "us-south"
  rg                      = local.resource_group_ids["service_rg"]
  scc_profile             = var.scc_enable ? var.scc_profile : ""
  event_notification_plan = var.scc_event_notification_plan
  tags                    = ["hpc", var.prefix]
  prefix                  = var.prefix
  cos_bucket              = var.scc_cos_bucket
  cos_instance_crn        = var.scc_cos_instance_crn
}
