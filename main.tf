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
  enable_ldap                = var.enable_ldap
  ldap_basedns               = var.ldap_basedns
  ldap_vsi_profile           = var.ldap_vsi_profile
  ldap_admin_password        = var.ldap_admin_password
  ldap_user_name             = var.ldap_user_name
  ldap_user_password         = var.ldap_user_password
  ldap_server                = var.ldap_server
  ldap_server_cert           = var.ldap_server_cert
  ldap_vsi_osimage_name      = var.ldap_vsi_osimage_name
  ldap_primary_ip            = local.ldap_private_ips
  afm_cos_config             = var.afm_cos_config
  afm_instances              = var.afm_instances
  scale_encryption_enabled   = var.scale_encryption_enabled
  scale_encryption_type      = var.scale_encryption_type
  gklm_instances             = var.gklm_instances
  gklm_instance_key_pair     = var.gklm_instance_key_pair
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

module "prepare_ansible_configuration" {
  source     = "./modules/git_utils"
  branch     = "scale_cloud"
  tag        = null
  clone_path = var.scale_ansible_repo_clone_path
  turn_on    = true
}

module "compute_inventory" {
  source                                           = "./modules/inventory"
  write_inventory                                  = (var.create_separate_namespaces == true && local.total_compute_cluster_instances > 0) ? 1 : 0
  hosts                                            = local.compute_hosts_private_ids
  inventory_path                                   = format("%s/compute_cluster_inventory.json", var.scale_ansible_repo_clone_path)
  clone_complete                                   = module.prepare_ansible_configuration.clone_complete
  bastion_user                                     = jsonencode(var.bastion_user)
  cloud_platform                                   = jsonencode("IBMCloud")
  resource_prefix                                  = jsonencode(format("%s.%s", var.prefix, var.vpc_compute_cluster_dns_domain))
  vpc_region                                       = jsonencode(local.region)
  vpc_availability_zones                           = jsonencode(var.zones)
  scale_version                                    = jsonencode(local.scale_version)
  filesystem_block_size                            = jsonencode("None")
  compute_cluster_filesystem_mountpoint            = jsonencode(var.compute_cluster_filesystem_mountpoint)
  bastion_instance_id                              = local.bastion_instance_id == null ? jsonencode("None") : jsonencode(local.bastion_instance_id)
  bastion_instance_public_ip                       = local.bastion_fip == null ? jsonencode("None") : jsonencode(local.bastion_fip)
  compute_cluster_instance_ids                     = jsonencode(concat((local.enable_sec_interface_compute ? local.compute_hosts_ids : local.compute_hosts_ids)))
  compute_cluster_instance_private_ips             = jsonencode(concat((local.enable_sec_interface_compute ? local.secondary_compute_hosts_private_ids : local.compute_hosts_private_ids)))
  compute_cluster_instance_private_dns_ip_map      = jsonencode([])
  storage_cluster_filesystem_mountpoint            = jsonencode("None")
  storage_cluster_instance_ids                     = jsonencode([])
  storage_cluster_instance_private_ips             = jsonencode([])
  storage_cluster_with_data_volume_mapping         = jsonencode({})
  storage_cluster_instance_private_dns_ip_map      = jsonencode({})
  storage_cluster_desc_instance_ids                = jsonencode([])
  storage_cluster_desc_instance_private_ips        = jsonencode([])
  storage_cluster_desc_data_volume_mapping         = jsonencode({})
  storage_cluster_desc_instance_private_dns_ip_map = jsonencode({})
  compute_cluster_instance_names                   = jsonencode(concat((local.enable_sec_interface_compute ? local.compute_hosts_names : local.compute_hosts_names)))
  storage_cluster_instance_names                   = jsonencode([])
  storage_subnet_cidr                              = jsonencode("")
  compute_subnet_cidr                              = jsonencode("")
  scale_remote_cluster_clustername                 = local.enable_mrot_conf ? jsonencode(format("%s.%s", var.resource_prefix, var.vpc_storage_cluster_dns_domain)) : jsonencode("")
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
  filesystem_mountpoint                            = var.scale_encryption_type == "key_protect" ? jsonencode(element(split("/", var.storage_cluster_filesystem_mountpoint), length(split("/", var.storage_cluster_filesystem_mountpoint)) - 1)) : jsonencode("")
}

module "storage_inventory" {
  source                                           = "./modules/inventory"
  hosts                                            = local.storage_hosts_private_ids
  write_inventory                                  = (var.create_separate_namespaces == true && local.total_storage_cluster_instances > 0) ? 1 : 0
  clone_complete                                   = module.prepare_ansible_configuration.clone_complete
  bastion_user                                     = jsonencode(var.bastion_user)
  inventory_path                                   = format("%s/storage_cluster_inventory.json", var.scale_ansible_repo_clone_path)
  cloud_platform                                   = jsonencode("IBMCloud")
  resource_prefix                                  = jsonencode(format("%s.%s", var.prefix, var.vpc_storage_cluster_dns_domain))
  vpc_region                                       = jsonencode(local.region)
  vpc_availability_zones                           = jsonencode(var.zones)
  scale_version                                    = jsonencode(local.scale_version)
  filesystem_block_size                            = jsonencode(var.filesystem_block_size)
  compute_cluster_filesystem_mountpoint            = jsonencode("None")
  bastion_instance_id                              = local.bastion_instance_id == null ? jsonencode("None") : jsonencode(local.bastion_instance_id)
  bastion_instance_public_ip                       = local.bastion_fip == null ? jsonencode("None") : jsonencode(local.bastion_fip)
  compute_cluster_instance_ids                     = jsonencode([])
  compute_cluster_instance_private_ips             = jsonencode([])
  compute_cluster_instance_private_dns_ip_map      = jsonencode({})
  storage_cluster_filesystem_mountpoint            = jsonencode(var.storage_cluster_filesystem_mountpoint)
  storage_cluster_instance_ids                     = jsonencode(concat(local.storage_cluster_instance_ids, local.storage_management_hosts_ids, local.tie_breaker_storage_instance_ids))
  storage_cluster_instance_private_ips             = jsonencode(concat(local.storage_cluster_instance_private_ips, local.storage_management_hosts_private_ips, local.tie_breaker_storage_instance_private_ips))
  storage_cluster_with_data_volume_mapping         = jsonencode({})
  storage_cluster_instance_private_dns_ip_map      = jsonencode({})
  storage_cluster_desc_instance_ids                = jsonencode(local.tie_breaker_storage_instance_ids)
  storage_cluster_desc_instance_private_ips        = jsonencode(local.tie_breaker_storage_instance_private_ips)
  storage_cluster_desc_data_volume_mapping         = jsonencode({})
  storage_cluster_desc_instance_private_dns_ip_map = jsonencode({})
  storage_cluster_instance_names                   = jsonencode(concat(local.storage_cluster_instance_names, local.storage_management_hosts_names, local.tie_breaker_storage_instance_names))
  compute_cluster_instance_names                   = jsonencode([])
  storage_subnet_cidr                              = jsonencode("")
  compute_subnet_cidr                              = jsonencode("")
  scale_remote_cluster_clustername                 = local.enable_mrot_conf ? jsonencode(format("%s.%s", var.prefix, var.vpc_compute_cluster_dns_domain)) : jsonencode("")
  protocol_cluster_instance_names                  = local.scale_ces_enabled == true ? jsonencode(local.protocol_hosts_names) : jsonencode([])
  client_cluster_instance_names                    = jsonencode([])
  protocol_cluster_reserved_names                  = jsonencode([])
  smb                                              = false
  nfs                                              = local.scale_ces_enabled == true ? true : false
  object                                           = false
  interface                                        = jsonencode([])
  export_ip_pool                                   = jsonencode([])
  filesystem                                       = local.scale_ces_enabled == true ? jsonencode("cesSharedRoot") : jsonencode("")
  mountpoint                                       = local.scale_ces_enabled == true ? jsonencode(var.storage_cluster_filesystem_mountpoint) : jsonencode("")
  protocol_gateway_ip                              = jsonencode("")
  filesets                                         = jsonencode(local.file_shares[0])
  afm_cos_bucket_details                           = jsonencode([])
  afm_config_details                               = jsonencode([])
  afm_cluster_instance_names                       = jsonencode(local.afm_hosts_names)
  filesystem_mountpoint                            = var.scale_encryption_type == "key_protect" ? jsonencode(element(split("/", var.storage_cluster_filesystem_mountpoint), length(split("/", var.storage_cluster_filesystem_mountpoint)) - 1)) : jsonencode("")
}

module "compute_playbook" {
  source           = "./modules/playbook"
  bastion_fip      = local.bastion_fip
  private_key_path = local.compute_private_key_path
  inventory_path   = local.compute_inventory_path
  playbook_path    = local.compute_playbook_path
  depends_on       = [module.compute_inventory]
}

# module "storage_playbook" {
#   source           = "./modules/playbook"
#   bastion_fip      = local.bastion_fip
#   private_key_path = local.storage_private_key_path
#   inventory_path   = local.storage_inventory_path
#   playbook_path    = local.storage_playbook_path
#   depends_on       = [module.storage_inventory]
# }

module "ldap_configuration" {
  source                     = "./modules/common/ldap_configuration"
  turn_on                    = var.enable_ldap && var.ldap_server == "null"
  clone_path                 = var.scale_ansible_repo_clone_path
  clone_complete             = module.prepare_ansible_configuration.clone_complete
  create_scale_cluster       = var.create_scale_cluster
  bastion_user               = jsonencode(var.bastion_user)
  write_inventory_complete   = module.storage_inventory.write_inventory_complete
  ldap_cluster_prefix        = var.prefix
  script_path                = format("%s/%s/modules/common/scripts/prepare_ldap_inv.py", var.scale_ansible_repo_clone_path, "ibm-spectrum-scale-cloud-install")
  using_jumphost_connection  = var.using_jumphost_connection
  bastion_instance_public_ip = local.bastion_fip
  bastion_ssh_private_key    = local.bastion_private_key_path
  ldap_basedns               = var.ldap_basedns
  ldap_admin_password        = var.ldap_admin_password
  ldap_user_name             = var.ldap_user_name
  ldap_user_password         = var.ldap_user_password
  ldap_server                = jsonencode(local.ldap_private_ips)
  meta_private_key           = local.ldap_private_key_path
  depends_on                 = [module.landing_zone_vsi.ldap_vsi_data]
}

module "compute_cluster_configuration" {
  source                          = "./modules/common/compute_configuration"
  turn_on                         = (var.create_separate_namespaces == true && local.total_compute_cluster_instances > 0) ? true : false
  clone_complete                  = module.prepare_ansible_configuration.clone_complete
  bastion_user                    = jsonencode(var.bastion_user)
  write_inventory_complete        = module.compute_inventory.write_inventory_complete
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
  bastion_instance_public_ip      = local.bastion_fip
  bastion_ssh_private_key         = local.bastion_private_key_path
  meta_private_key                = local.compute_private_key_path
  scale_version                   = local.scale_version
  spectrumscale_rpms_path         = var.spectrumscale_rpms_path
  enable_mrot_conf                = local.enable_mrot_conf ? "True" : "False"
  enable_ces                      = "False"
  enable_afm                      = "False"
  scale_encryption_enabled        = var.scale_encryption_enabled
  scale_encryption_admin_password = var.scale_encryption_admin_password
  scale_encryption_servers        = var.scale_encryption_enabled ? jsonencode(local.gklm_hosts_private_ips) : null
  enable_ldap                     = var.enable_ldap
  ldap_basedns                    = var.ldap_basedns
  ldap_server                     = local.ldap_private_ips[0]
  ldap_admin_password             = var.ldap_admin_password
  enable_key_protect              = var.scale_encryption_type == "key_protect" ? "True" : "False"
  depends_on                      = [module.ldap_configuration]
}

module "storage_cluster_configuration" {
  source                              = "./modules/common/storage_configuration"
  turn_on                             = (var.create_separate_namespaces == true && local.total_storage_cluster_instances > 0) ? true : false
  clone_complete                      = module.prepare_ansible_configuration.clone_complete
  bastion_user                        = jsonencode(var.bastion_user)
  write_inventory_complete            = module.storage_inventory.write_inventory_complete
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
  max_data_replicas                   = 3
  max_metadata_replicas               = 3
  default_metadata_replicas           = 2
  default_data_replicas               = 2
  bastion_instance_public_ip          = local.bastion_fip
  bastion_ssh_private_key             = local.bastion_private_key_path
  meta_private_key                    = local.storage_private_key_path
  scale_version                       = local.scale_version
  spectrumscale_rpms_path             = var.spectrumscale_rpms_path
  enable_mrot_conf                    = local.enable_mrot_conf ? "True" : "False"
  enable_ces                          = local.scale_ces_enabled == true ? "True" : "False"
  enable_afm                          = local.enable_afm == true ? "True" : "False"
  scale_encryption_enabled            = var.scale_encryption_enabled
  scale_encryption_type               = var.scale_encryption_type != null ? var.scale_encryption_type : null
  scale_encryption_admin_password     = var.scale_encryption_admin_password
  scale_encryption_servers            = var.scale_encryption_enabled && var.scale_encryption_type == "gklm" ? jsonencode(local.gklm_hosts_private_ips) : null
  enable_ldap                         = var.enable_ldap
  ldap_basedns                        = var.ldap_basedns
  ldap_server                         = local.ldap_private_ips[0]
  ldap_admin_password                 = var.ldap_admin_password
  ldap_server_cert                    = "hai"
  enable_key_protect                  = var.scale_encryption_type == "key_protect" ? "True" : "False"
  depends_on                          = [module.ldap_configuration]
}

output "ldap_configuration" {
  value = module.ldap_configuration
}


output "storage_cluster_configuration" {
  value = module.storage_cluster_configuration
}
