module "landing_zone" {
  source                        = "./modules/landing_zone"
  enable_landing_zone           = var.enable_landing_zone
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
  static_compute_instances      = var.static_compute_instances
  management_instances          = var.management_instances
  dns_domain_names              = var.dns_domain_names
}

module "landing_zone_vsi" {
  count                      = var.enable_deployer == false ? 1 : 0
  source                     = "./modules/landing_zone_vsi"
  resource_group             = var.resource_group
  prefix                     = var.prefix
  zones                      = var.zones
  vpc_id                     = local.vpc_id
  bastion_security_group_id  = var.bastion_security_group_id
  bastion_public_key_content = local.bastion_public_key_content
  compute_public_key_content = var.compute_public_key_content
  compute_private_key_content= var.compute_private_key_content
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
  enable_ldap                = var.enable_ldap
  ldap_instances             = var.ldap_instances
  ldap_server                = var.ldap_server
  ldap_instance_key_pair     = local.ldap_instance_key_pair
  scale_encryption_enabled   = var.scale_encryption_enabled
  scale_encryption_type      = var.scale_encryption_type
  gklm_instance_key_pair     = local.gklm_instance_key_pair
  gklm_instances             = var.gklm_instances
}

resource "local_sensitive_file" "prepare_tf_input" {
  count    = var.enable_deployer == true ? 1 : 0
  content  = <<EOT
{
  "scheduler": "${local.scheduler}",
  "ibmcloud_api_key": "${var.ibmcloud_api_key}",
  "resource_group": "${var.resource_group}",
  "prefix": "${var.prefix}",
  "zones": ${local.zones},
  "enable_landing_zone": false,
  "enable_deployer": false,
  "enable_bastion": false,
  "bastion_fip": "${local.bastion_fip}",
  "compute_ssh_keys": ${local.list_compute_ssh_keys},
  "storage_ssh_keys": ${local.list_storage_ssh_keys},
  "storage_instances": ${local.list_storage_instances},
  "management_instances": ${local.list_management_instances},
  "protocol_instances": ${local.list_protocol_instances},
  "ibm_customer_number": "${var.ibm_customer_number}",
  "static_compute_instances": ${local.list_compute_instances},
  "client_instances": ${local.list_client_instances},
  "client_ssh_keys": ${local.list_client_ssh_keys},
  "enable_cos_integration": ${var.enable_cos_integration},
  "enable_atracker": ${var.enable_atracker},
  "enable_vpc_flow_logs": ${var.enable_vpc_flow_logs},
  "allowed_cidr": ${local.allowed_cidr},
  "vpc_id": "${local.vpc_id}",
  "vpc": "${local.vpc}",
  "storage_subnets": ${local.list_storage_subnets},
  "protocol_subnets": ${local.list_protocol_subnets},
  "compute_subnets": ${local.list_compute_subnets},
  "client_subnets": ${local.list_client_subnets},
  "bastion_subnets": ${local.list_bastion_subnets},
  "dns_domain_names": ${local.dns_domain_names},
  "compute_public_key_content": ${local.compute_public_key_content},
  "compute_private_key_content": ${local.compute_private_key_content},
  "bastion_security_group_id": "${local.bastion_security_group_id}",
  "deployer_hostname": "${local.deployer_hostname}",
  "deployer_ip": "${local.deployer_ip}",
  "ldap_instances": ${local.list_ldap_instances},
  "enable_ldap": ${var.enable_ldap},
  "ldap_server": ${local.ldap_server},
  "ldap_basedns": ${local.ldap_basedns},
  "ldap_instance_key_pair": ${local.list_ldap_ssh_keys},
  "ldap_admin_password": "${local.ldap_admin_password}",
  "ldap_user_name": "${var.ldap_user_name}",
  "ldap_user_password": "${var.ldap_user_password}",
  "ldap_server_cert": "${local.ldap_server_cert}",
  "afm_instances": ${local.list_afm_instances},
  "scale_encryption_enabled": ${var.scale_encryption_enabled},
  "scale_encryption_type": ${local.scale_encryption_type},
  "gklm_instance_key_pair": ${local.list_gklm_ssh_keys},
  "gklm_instances": ${local.list_gklm_instances},
  "scale_encryption_admin_password": "${local.scale_encryption_admin_password}",
  "filesystem_config": ${local.filesystem_config}
}    
EOT
  filename = local.schematics_inputs_path
}

resource "null_resource" "tf_resource_provisioner" {
  count = var.enable_deployer == true ? 1 : 0
  connection {
    type                = "ssh"
    host                = flatten(module.deployer.deployer_vsi_data[*].list)[0].ipv4_address
    user                = "vpcuser"
    private_key         = local.bastion_private_key_content
    bastion_host        = local.bastion_fip
    bastion_user        = "ubuntu"
    bastion_private_key = local.bastion_private_key_content
    timeout             = "60m"
  }

  provisioner "file" {
    source      = local.schematics_inputs_path
    destination = local.remote_inputs_path
  }

  provisioner "remote-exec" {
    inline = [
      "if [ ! -d ${local.remote_terraform_path} ]; then sudo git clone -b ${local.da_hpc_repo_tag} ${local.da_hpc_repo_url} ${local.remote_terraform_path}; fi",
      "if [ ! -d ${local.remote_ansible_path}/${local.scale_cloud_infra_repo_name}/collections/ansible_collections/ibm/spectrum_scale ]; then sudo git clone -b ${local.scale_cloud_infra_repo_tag} ${local.scale_cloud_infra_repo_url} ${local.remote_ansible_path}/${local.scale_cloud_infra_repo_name}/collections/ansible_collections/ibm/spectrum_scale; fi",
      "sudo ln -fs /usr/local/bin/ansible-playbook /usr/bin/ansible-playbook",
      "sudo cp ${local.remote_inputs_path} ${local.remote_terraform_path}",
      "export TF_LOG=${var.TF_LOG} && sudo -E terraform -chdir=${local.remote_terraform_path} init && sudo -E terraform -chdir=${local.remote_terraform_path} apply -parallelism=${var.TF_PARALLELISM} -auto-approve"
    ]
  }

  triggers = {
    always_run = timestamp()
  }

  depends_on = [
    module.deployer,
    local_sensitive_file.prepare_tf_input
  ]
}

resource "null_resource" "cluster_destroyer" {
  count    = var.enable_deployer == true ? 1 : 0
  triggers = {
    conn_host                  = flatten(module.deployer.deployer_vsi_data[*].list)[0].ipv4_address
    conn_private_key           = local.bastion_private_key_content
    conn_bastion_host          = local.bastion_fip
    conn_bastion_private_key   = local.bastion_private_key_content
    conn_ibmcloud_api_key      = var.ibmcloud_api_key
    conn_remote_terraform_path = local.remote_terraform_path
    conn_terraform_log_level   = var.TF_LOG
  }

  connection {
    type                = "ssh"
    host                = self.triggers.conn_host
    user                = "vpcuser"
    private_key         = self.triggers.conn_private_key
    bastion_host        = self.triggers.conn_bastion_host
    bastion_user        = "ubuntu"
    bastion_private_key = self.triggers.conn_bastion_private_key
    timeout             = "60m"
  }

  provisioner "remote-exec" {
    when       = destroy
    on_failure = fail
    inline = [
      "export TF_LOG=${self.triggers.conn_terraform_log_level} && sudo -E terraform -chdir=${self.triggers.conn_remote_terraform_path} destroy -auto-approve"
    ]
  }
}

module "file_storage" {
  count              = var.enable_deployer == false && var.scheduler != "null" ? 1 : 0 
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
  depends_on      = [ module.dns ]
}

module "storage_dns_records" {
  count           = var.enable_deployer == false ? 1 : 0
  source          = "./modules/dns_record"
  dns_instance_id = local.dns_instance_id
  dns_zone_id     = local.storage_dns_zone_id
  dns_records     = local.storage_dns_records
  depends_on      = [ module.dns ]
}

module "protocol_dns_records" {
  count           = var.enable_deployer == false ? 1 : 0
  source          = "./modules/dns_record"
  dns_instance_id = local.dns_instance_id
  dns_zone_id     = local.protocol_dns_zone_id
  dns_records     = local.protocol_dns_records
  depends_on      = [ module.dns ]
}

module "client_dns_records" {
  count           = var.enable_deployer == false ? 1 : 0
  source          = "./modules/dns_record"
  dns_instance_id = local.dns_instance_id
  dns_zone_id     = local.client_dns_zone_id
  dns_records     = local.client_dns_records
  depends_on      = [ module.dns ]
}

module "gklm_dns_records" {
  count           = var.enable_deployer == false ? 1 : 0
  source          = "./modules/dns_record"
  dns_instance_id = local.dns_instance_id
  dns_zone_id     = local.gklm_dns_zone_id
  dns_records     = local.gklm_dns_records
  depends_on      = [ module.dns ]
}

resource "time_sleep" "wait_60_seconds" {
  create_duration = "60s"
  depends_on          = [ module.storage_dns_records, module.protocol_dns_records, module.compute_dns_records ]
}

module "write_compute_cluster_inventory" {
  count                                            = var.enable_deployer == false ? 1 : 0 
  source                                           = "./modules/write_inventory"
  json_inventory_path                              = format("%s/compute_cluster_inventory.json", local.json_inventory_path)
  lsf_masters                                      = local.management_nodes
  lsf_servers                                      = local.compute_nodes
  lsf_clients                                      = local.client_nodes
  gui_hosts                                        = local.gui_hosts
  db_hosts                                         = local.db_hosts
  my_cluster_name                                  = var.prefix
  ha_shared_dir                                    = local.ha_shared_dir
  nfs_install_dir                                  = local.nfs_install_dir
  Enable_Monitoring                                = local.Enable_Monitoring
  lsf_deployer_hostname                            = local.lsf_deployer_hostname
  bastion_user                                     = jsonencode(var.bastion_user)
  bastion_instance_id                              = var.bastion_instance_id == null ? jsonencode("None") : jsonencode(var.bastion_instance_id)
  bastion_instance_public_ip                       = var.bastion_fip == null ? jsonencode("None") : jsonencode(var.bastion_fip)
  cloud_platform                                   = jsonencode("IBMCloud")
  resource_prefix                                  = jsonencode(format("%s.%s", var.prefix, var.dns_domain_names["compute"])) 
  vpc_region                                       = jsonencode(local.region)
  vpc_availability_zones                           = jsonencode(var.zones)
  scale_version                                    = jsonencode(local.scale_version)
  compute_cluster_filesystem_mountpoint            = jsonencode("/gpfs/fs1") #var.compute_cluster_filesystem_mountpoint)
  storage_cluster_filesystem_mountpoint            = jsonencode("None")
  filesystem_block_size                            = jsonencode("None")
  compute_cluster_instance_private_ips             = jsonencode(concat((local.enable_sec_interface_compute ? local.compute_instance_private_ips : local.compute_instance_private_ips)))
  compute_cluster_instance_ids                     = jsonencode(concat((local.enable_sec_interface_compute ? local.compute_instance_ids : local.compute_instance_ids)))
  compute_cluster_instance_names                   = jsonencode(concat((local.enable_sec_interface_compute ? local.compute_instance_names : local.compute_instance_names)))
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
  filesystem_mountpoint                            =  var.scale_encryption_type == "key_protect" ? (var.storage_instances[*]["filesystem"] != "" ? var.storage_instances[*]["filesystem"] : jsonencode(var.filesystem_config[0]["filesystem"])) : jsonencode("")
  depends_on                                       = [ time_sleep.wait_60_seconds ] 
}

module "write_storage_cluster_inventory" {
  count                                            = var.enable_deployer == false ? 1 : 0 
  source                                           = "./modules/write_inventory"
  json_inventory_path                              = format("%s/storage_cluster_inventory.json", local.json_inventory_path)
  lsf_masters                                      = local.management_nodes
  lsf_servers                                      = local.compute_nodes
  lsf_clients                                      = local.client_nodes
  gui_hosts                                        = local.gui_hosts
  db_hosts                                         = local.db_hosts
  my_cluster_name                                  = local.my_cluster_name
  ha_shared_dir                                    = local.ha_shared_dir
  nfs_install_dir                                  = local.nfs_install_dir
  Enable_Monitoring                                = local.Enable_Monitoring
  lsf_deployer_hostname                            = local.lsf_deployer_hostname
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
  storage_cluster_instance_private_ips             = jsonencode(local.storage_instance_private_ips)
  storage_cluster_instance_ids                     = jsonencode(local.storage_instance_ids)
  storage_cluster_instance_names                   = jsonencode(local.storage_instance_names)
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
  export_ip_pool                                   = local.scale_ces_enabled == true ? jsonencode(local.protocol_instance_private_ips) : jsonencode([])
  filesystem                                       = local.scale_ces_enabled == true ? jsonencode("cesSharedRoot") : jsonencode("")
  mountpoint                                       = local.scale_ces_enabled == true ? jsonencode(var.filesystem_config[0]["mount_point"]) : jsonencode("")
  protocol_gateway_ip                              = jsonencode("")
  filesets                                         = jsonencode(local.fileset_size_map)
  afm_cos_bucket_details                           = jsonencode([])
  afm_config_details                               = jsonencode([])
  afm_cluster_instance_names                       = jsonencode(local.afm_instance_names)
  filesystem_mountpoint                            = var.scale_encryption_type == "key_protect" ? (var.storage_instances[*]["filesystem"] != "" ? var.storage_instances[*]["filesystem"] : jsonencode(var.filesystem_config[0]["filesystem"])) : jsonencode("")
  depends_on                                       = [ time_sleep.wait_60_seconds ]
}

locals {
  fileset_size_map = try({ for details in var.file_shares : details.mount_path => details.size }, {})
}

module "write_client_cluster_inventory" {
  count                                            = var.enable_deployer == false ? 1 : 0 
  source                                           = "./modules/write_inventory"
  json_inventory_path                              = format("%s/client_cluster_inventory.json", local.json_inventory_path)
  lsf_masters                                      = local.management_nodes
  lsf_servers                                      = local.compute_nodes
  lsf_clients                                      = local.client_nodes
  gui_hosts                                        = local.gui_hosts
  db_hosts                                         = local.db_hosts
  my_cluster_name                                  = var.prefix
  ha_shared_dir                                    = local.ha_shared_dir
  nfs_install_dir                                  = local.nfs_install_dir
  Enable_Monitoring                                = local.Enable_Monitoring
  lsf_deployer_hostname                            = local.lsf_deployer_hostname
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

module "compute_inventory" {
  count               = var.enable_deployer == false ? 1 : 0
  source              = "./modules/inventory"
  hosts               = local.compute_hosts
  inventory_path      = local.compute_inventory_path
  name_mount_path_map = local.fileshare_name_mount_path_map
  scheduler           = var.scheduler
  depends_on          = [ module.write_compute_cluster_inventory ]
}

module "storage_cluster_configuration" {
  count                               = var.enable_deployer == false ? 1 : 0
  source                              = "./modules/common/storage_configuration"
  turn_on                             = (var.create_separate_namespaces == true && local.storage_instance_count > 0) ? true : false
  bastion_user                        = jsonencode(var.bastion_user)
  write_inventory_complete            = module.write_storage_cluster_inventory[0].write_inventory_complete
  inventory_format                    = var.inventory_format
  create_scale_cluster                = var.create_scale_cluster
  clone_path                          = var.scale_ansible_repo_clone_path
  inventory_path                      = format("%s/storage_cluster_inventory.json", local.json_inventory_path)
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
  ldap_server                         = local.ldap_instance_private_ips[0]
  ldap_admin_password                 = var.ldap_admin_password
  ldap_server_cert                    = var.ldap_server_cert
  enable_key_protect                  = var.scale_encryption_type == "key_protect" ? "True" : "False"
  depends_on                          = [module.write_storage_cluster_inventory]
}

# module "storage_inventory" {
#   count               = var.enable_deployer == false ? 1 : 0
#   source              = "./modules/inventory"
#   hosts               = local.storage_hosts
#   inventory_path      = local.storage_inventory_path
#   name_mount_path_map = local.fileshare_name_mount_path_map
#   scheduler           = var.scheduler
#   depends_on          = [ module.write_storage_cluster_inventory ]
# }

module "compute_playbook" {
  count            = var.enable_deployer == false ? 1 : 0
  source           = "./modules/playbook"
  bastion_fip      = local.bastion_fip
  private_key_path = local.compute_private_key_path
  inventory_path   = local.compute_inventory_path
  playbook_path    = local.compute_playbook_path
  enable_bastion   = var.enable_bastion
  enable_scale     = var.enable_scale
  depends_on       = [ module.compute_inventory ]
}

# module "storage_playbook" {
#   count            = var.enable_deployer == false && var.scheduler == null ? 1 : 0
#   source           = "./modules/playbook"
#   bastion_fip      = local.bastion_fip
#   private_key_path = local.storage_private_key_path
#   inventory_path   = local.storage_inventory_path
#   playbook_path    = local.storage_playbook_path
#   enable_bastion   = var.enable_bastion
#   enable_scale     = var.enable_scale
#   scheduler        = var.scheduler
#   depends_on       = [ module.write_storage_cluster_inventory ]
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
  # scc_profile_version     = var.scc_profile != "" && var.scc_profile != null ? var.scc_profile_version : ""
  event_notification_plan = var.scc_event_notification_plan
  tags                    = ["hpc", var.prefix]
  prefix                  = var.prefix
  cos_bucket              = [for name in module.landing_zone.cos_buckets_names : name if strcontains(name, "scc-bucket")][0]
  cos_instance_crn        = module.landing_zone.cos_instance_crns[0]
}
