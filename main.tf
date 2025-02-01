module "landing_zone" {
  source                 = "./modules/landing_zone"
  enable_landing_zone    = var.enable_landing_zone
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

  # New Variables
  ibmcloud_api_key           = var.ibmcloud_api_key
  ibm_customer_number        = var.ibm_customer_number
  storage_instances          = var.storage_instances
  management_instances       = var.management_instances
  protocol_instances         = var.protocol_instances
  client_instances           = var.client_instances
  static_compute_instances   = var.static_compute_instances
  storage_ssh_keys           = local.storage_ssh_keys
  compute_ssh_keys           = local.compute_ssh_keys
  storage_subnets            = local.storage_subnets
  protocol_subnets           = local.protocol_subnets
  compute_subnets            = local.compute_subnets
  client_subnets             = local.client_subnets
  bastion_fip                = local.bastion_fip
  dns_instance_id            = var.dns_instance_id
  dns_custom_resolver_id     = var.dns_custom_resolver_id
  dns_domain_names           = var.dns_domain_names
  vpc                        = local.vpc
  resource_group_id          = local.resource_group_ids["workload_rg"]
  enable_vpc_flow_logs       = var.enable_vpc_flow_logs
  key_management             = var.key_management
  enable_atracker            = var.enable_atracker
  enable_cos_integration     = var.enable_cos_integration
}

module "landing_zone_vsi" {
  count                      = var.enable_deployer == false ? 1 : 0
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
  enable_bastion             = var.enable_bastion
}

resource "local_sensitive_file" "prepare_tf_input" {
  count                      = var.enable_deployer == true ? 1 : 0
  content  = <<EOT
{
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
  "dns_domain_names": ${local.dns_domain_names}
}    
EOT
  filename = local.schematics_inputs_path
}

resource "time_sleep" "deployer_wait_120_seconds" {
  create_duration = "120s"
  depends_on      = [module.deployer]
}

resource "null_resource" "tf_resource_provisioner" {
  #count                 = var.enable_deployer == true ? 1 : 0
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
      "sudo cp ${local.remote_inputs_path} ${local.remote_terraform_path}",
      "export TF_LOG=${var.TF_LOG} && sudo -E terraform -chdir=${local.remote_terraform_path} init && sudo -E terraform -chdir=${local.remote_terraform_path} apply -parallelism=${var.TF_PARALLELISM} -auto-approve"
    ]
  }

  triggers = {
    always_run = timestamp()
  }

  depends_on = [
    time_sleep.deployer_wait_120_seconds,
    local_sensitive_file.prepare_tf_input
  ]
}

resource "null_resource" "cluster_destroyer" {
  #count                 = var.enable_deployer == true ? 1 : 0
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
}

module "storage_dns_records" {
  count           = var.enable_deployer == false ? 1 : 0 
  source          = "./modules/dns_record"
  dns_instance_id = local.dns_instance_id
  dns_zone_id     = local.storage_dns_zone_id
  dns_records     = local.storage_dns_records
}

module "protocol_dns_records" {
  count           = var.enable_deployer == false ? 1 : 0 
  source          = "./modules/dns_record"
  dns_instance_id = local.dns_instance_id
  dns_zone_id     = local.protocol_dns_zone_id
  dns_records     = local.protocol_dns_records
}

resource "time_sleep" "wait_60_seconds" {
  count           = var.enable_deployer == false ? 1 : 0 
  create_duration = "60s"
  depends_on      = [ module.storage_dns_records, module.protocol_dns_records, module.compute_dns_records ]
}

module "write_compute_cluster_inventory" {
  count                 = var.enable_deployer == false ? 1 : 0 
  source                = "./modules/write_inventory"
  json_inventory_path   = local.json_inventory_path
  lsf_masters           = local.management_nodes
  lsf_servers           = local.compute_nodes
  lsf_clients           = local.client_nodes
  gui_hosts             = local.gui_hosts
  db_hosts              = local.db_hosts
  my_cluster_name       = var.prefix
  ha_shared_dir         = local.ha_shared_dir
  nfs_install_dir       = local.nfs_install_dir
  Enable_Monitoring     = local.Enable_Monitoring
  lsf_deployer_hostname = local.lsf_deployer_hostname
  depends_on            = [ time_sleep.wait_60_seconds ]
}

module "write_storage_cluster_inventory" {
  count                 = var.enable_deployer == false ? 1 : 0 
  source                = "./modules/write_inventory"
  json_inventory_path   = local.json_inventory_path
  lsf_masters           = local.management_nodes
  lsf_servers           = local.compute_nodes
  lsf_clients           = local.client_nodes
  gui_hosts             = local.gui_hosts
  db_hosts              = local.db_hosts
  my_cluster_name       = var.prefix
  ha_shared_dir         = local.ha_shared_dir
  nfs_install_dir       = local.nfs_install_dir
  Enable_Monitoring     = local.Enable_Monitoring
  lsf_deployer_hostname = local.lsf_deployer_hostname
  depends_on            = [ time_sleep.wait_60_seconds ]
}

module "compute_inventory" {
  count               = var.enable_deployer == false ? 1 : 0 
  source              = "./modules/inventory"
  hosts               = local.compute_hosts
  inventory_path      = local.compute_inventory_path
  name_mount_path_map = local.fileshare_name_mount_path_map
  depends_on          = [ module.write_compute_cluster_inventory ]
}

module "storage_inventory" {
  source              = "./modules/inventory"
  count               = var.enable_deployer == false ? 1 : 0
  hosts               = local.storage_hosts
  inventory_path      = local.storage_inventory_path
  name_mount_path_map = local.fileshare_name_mount_path_map
  depends_on          = [ module.write_storage_cluster_inventory ]
}

module "compute_playbook" {
  source           = "./modules/playbook"
  count            = var.enable_deployer == false ? 1 : 0
  bastion_fip      = local.bastion_fip
  private_key_path = local.compute_private_key_path
  inventory_path   = local.compute_inventory_path
  playbook_path    = local.compute_playbook_path
  enable_bastion   = var.enable_bastion
  depends_on       = [ module.compute_inventory ]
}

module "storage_playbook" {
  count            = var.enable_deployer == false ? 1 : 0
  source           = "./modules/playbook"
  bastion_fip      = local.bastion_fip
  private_key_path = local.storage_private_key_path
  inventory_path   = local.storage_inventory_path
  playbook_path    = local.storage_playbook_path
  enable_bastion   = var.enable_bastion
  depends_on       = [ module.storage_inventory ]
}

