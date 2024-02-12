module "landing_zone" {
  source = "../../modules/landing_zone"
  # TODO: Add logic
  allowed_cidr           = var.allowed_cidr
  compute_subnets_cidr   = var.compute_subnets_cidr
  cos_instance_name      = var.cos_instance_name
  # enable_atracker        = var.enable_atracker
  enable_cos_integration = var.enable_cos_integration
  enable_vpc_flow_logs   = var.enable_vpc_flow_logs
  enable_vpn             = var.enable_vpn
  # hpcs_instance_name     = var.hpcs_instance_name
  ibmcloud_api_key       = var.ibmcloud_api_key
  key_management         = var.key_management
  kms_instance_name        = var.kms_instance_name
  kms_key_name           = var.kms_key_name
  ssh_keys               = var.bastion_ssh_keys
  bastion_subnets_cidr   = var.bastion_subnets_cidr
  # management_instances   = var.management_instances
  # compute_instances      = var.static_compute_instances
  network_cidr           = var.network_cidr
  # placement_strategy     = var.placement_strategy
  prefix                 = var.prefix
  # protocol_instances     = var.protocol_instances
  # protocol_subnets_cidr  = var.protocol_subnets_cidr
  resource_group         = var.resource_group
  # storage_instances      = var.storage_instances
  # storage_subnets_cidr   = var.storage_subnets_cidr
  vpc                    = var.vpc
  subnet_id             = var.subnet_id
  # vpn_peer_address       = var.vpn_peer_address
  # vpn_peer_cidr          = var.vpn_peer_cidr
  # vpn_preshared_key      = var.vpn_preshared_key
  zones                  = var.zones
  management_node_count  = var.management_node_count
  public_gateways = local.public_gateways
}

module "bootstrap" {
  source                     = "./../../modules/bootstrap"
  ibmcloud_api_key           = var.ibmcloud_api_key
  resource_group             = local.resource_groups["workload_rg"]
  prefix                     = var.prefix
  zones                      = var.zones
  vpc_id                     = local.vpc_id
  network_cidr               = var.vpc != null && length(var.subnet_id) > 0 ? var.existing_subnet_cidrs : split(",", var.network_cidr)
  # enable_bastion             = var.enable_bastion
  bastion_subnets            = local.bastion_subnets
  # peer_cidr_list             = var.peer_cidr_list
  # enable_bootstrap           = var.enable_bootstrap
  # bootstrap_instance_profile = var.bootstrap_instance_profile
  ssh_keys                   = var.bastion_ssh_keys
  allowed_cidr               = var.allowed_cidr
  kms_encryption_enabled     = local.kms_encryption_enabled
  boot_volume_encryption_key = local.boot_volume_encryption_key
  existing_kms_instance_guid = local.existing_kms_instance_guid
  compute_security_group_id  = local.compute_security_group_id
  skip_iam_authorization_policy = var.skip_iam_authorization_policy
}

module "landing_zone_vsi" {
  source                     = "../../modules/landing_zone_vsi"
  ibmcloud_api_key           = var.ibmcloud_api_key
  resource_group             = local.resource_groups["workload_rg"]
  prefix                     = var.prefix
  zones                      = var.zones
  vpc_id                     = local.vpc_id
  bastion_security_group_id  = local.bastion_security_group_id
  bastion_public_key_content = local.bastion_public_key_content
  # login_subnets              = local.login_subnets
  # login_ssh_keys             = var.login_ssh_keys
  # login_image_name           = var.login_image_name
  # keys               = local.ssh_key_id_list
  # login_instances               = var.login_instances
  compute_subnets               = local.compute_subnets
  compute_ssh_keys              = var.compute_ssh_keys
  management_image_name         = var.management_image_name
  # management_instances          = var.management_instances
  # static_compute_instances      = var.static_compute_instances
  # dynamic_compute_instances     = var.dynamic_compute_instances
  compute_image_name            = var.compute_image_name
  # storage_subnets               = local.storage_subnets
  # storage_ssh_keys              = var.storage_ssh_keys
  # storage_instances             = var.storage_instances
  # storage_image_name            = var.storage_image_name
  # protocol_subnets              = local.protocol_subnets
  # protocol_instances            = var.protocol_instances
  # nsd_details                   = var.nsd_details
  dns_domain_names              = var.dns_domain_names
  kms_encryption_enabled        = local.kms_encryption_enabled
  boot_volume_encryption_key    = local.boot_volume_encryption_key
  share_path                    = local.share_path
  hyperthreading_enabled        = var.hyperthreading_enabled
  app_center_gui_pwd            = var.app_center_gui_pwd
  enable_app_center             = var.enable_app_center
  contract_id                   = var.contract_id
  cluster_id                    = var.cluster_id
  management_node_count         = var.management_node_count
  management_node_instance_type = var.management_node_instance_type
  file_share                    = module.file_storage.mount_paths_excluding_first
  mount_path                    = var.file_shares
  login_node_instance_type      = var.login_node_instance_type
  existing_kms_instance_guid    = local.existing_kms_instance_guid
  bastion_subnets               = local.bastion_subnets
  ssh_keys                      = var.bastion_ssh_keys
  enable_ldap                   = var.enable_ldap
  ldap_basedns                  = var.ldap_basedns
  subnet_id                     = var.subnet_id
  login_private_ips             = join("", local.login_private_ips)
  ldap_vsi_profile              = var.ldap_vsi_profile
  ldap_admin_password           = var.ldap_admin_password
  ldap_user_name                = var.ldap_user_name
  ldap_user_password            = var.ldap_user_password
  ldap_server                   = var.ldap_server
  ldap_vsi_osimage_name         = var.ldap_vsi_osimage_name
  ldap_primary_ip               = local.ldap_private_ips
}

module "file_storage" {
  source             = "../../modules/file_storage"
  ibmcloud_api_key   = var.ibmcloud_api_key
  zone               = var.zones[0] # always the first zone
  resource_group     = local.resource_groups["workload_rg"]
  file_shares        = local.file_shares
  encryption_key_crn = local.boot_volume_encryption_key
  security_group_ids = local.compute_security_group_id
  subnet_id          = local.compute_subnet_id
  prefix             = var.prefix
}

module "dns" {
  source                 = "./../../modules/dns"
  ibmcloud_api_key       = var.ibmcloud_api_key
  prefix                 = var.prefix
  resource_group_id      = local.resource_groups["service_rg"]
  vpc_crn                = local.vpc_crn
  subnets_crn            = local.compute_subnets_crn
  dns_instance_id        = var.dns_instance_id
  #dns_custom_resolver_id = var.dns_custom_resolver_id
  dns_domain_names       = values(var.dns_domain_names)
}

###################################################
# TODO : Added a new variable called dns_domain_names to support the single domain feature and need to rework
##################################################
module "compute_dns_records" {
  source           = "./../../modules/dns_record"
  ibmcloud_api_key = var.ibmcloud_api_key
  dns_instance_id  = local.dns_instance_id
  dns_zone_id      = local.compute_dns_zone_id
  dns_records      = local.compute_dns_records
  dns_domain_names = var.dns_domain_names
}

module "compute_candidate_dns_records" {
  source           = "./../../modules/dns_record"
  ibmcloud_api_key = var.ibmcloud_api_key
  dns_instance_id  = local.dns_instance_id
  dns_zone_id      = local.compute_dns_zone_id
  dns_records      = local.mgmt_candidate_dns_records
  dns_domain_names = var.dns_domain_names
}

module "login_vsi_dns_records" {
  source           = "./../../modules/dns_record"
  ibmcloud_api_key = var.ibmcloud_api_key
  dns_instance_id  = local.dns_instance_id
  dns_zone_id      = local.compute_dns_zone_id
  dns_records      = local.login_vsi_dns_records
  dns_domain_names = var.dns_domain_names
}

module "ldap_vsi_dns_records" {
  source           = "./../../modules/dns_record"
  ibmcloud_api_key = var.ibmcloud_api_key
  dns_instance_id  = local.dns_instance_id
  dns_zone_id      = local.compute_dns_zone_id
  dns_records      = local.ldap_vsi_dns_records
  dns_domain_names = var.dns_domain_names
}

# module "storage_dns_records" {
#   source           = "./../../modules/dns_record"
#   ibmcloud_api_key = var.ibmcloud_api_key
#   dns_instance_id  = local.dns_instance_id
#   dns_zone_id      = local.storage_dns_zone_id
#   dns_records      = local.storage_dns_records
# }

# module "protocol_dns_records" {
#   source           = "./../../modules/dns_record"
#   ibmcloud_api_key = var.ibmcloud_api_key
#   dns_instance_id  = local.dns_instance_id
#   dns_zone_id      = local.protocol_dns_zone_id
#   dns_records      = local.protocol_dns_records
# }

module "compute_inventory" {
  source         = "./../../modules/inventory"
  hosts          = local.compute_hosts
  user           = local.cluster_user
  server_name    = "[HPCAASCluster]"
  inventory_path = local.compute_inventory_path
}

module "bastion_inventory" {
  source         = "./../../modules/inventory"
  hosts          = local.bastion_host
  user           = local.login_user
  server_name    = "[BastionServer]"
  inventory_path = local.bastion_inventory_path
}

module "login_inventory" {
  source         = "./../../modules/inventory"
  hosts          = local.login_host
  user           = local.cluster_user
  server_name    = "[LoginServer]"
  inventory_path = local.login_inventory_path
}

module "ldap_inventory" {
  source         = "./../../modules/inventory"
  hosts          = local.ldap_host
  user           = local.ldap_user
  server_name    = "[LDAPServer]"
  inventory_path = local.ldap_inventory_path
}

# module "storage_inventory" {
#   source         = "./../../modules/inventory"
#   hosts          = local.storage_hosts
#   inventory_path = local.storage_inventory_path
# }

# module "compute_playbook" {
#   source           = "./../../modules/playbook"
#   bastion_fip      = local.bastion_fip
#   private_key_path = local.compute_private_key_path
#   inventory_path   = local.compute_inventory_path
#   playbook_path    = local.compute_playbook_path
#   depends_on       = [module.compute_inventory]
# }

# module "storage_playbook" {
#   source           = "./../../modules/playbook"
#   bastion_fip      = local.bastion_fip
#   private_key_path = local.storage_private_key_path
#   inventory_path   = local.storage_inventory_path
#   playbook_path    = local.storage_playbook_path
#   depends_on       = [module.storage_inventory]
# }

module "check_cluster_status" {
  source              = "./../../modules/null/remote_exec"
  cluster_host        = [local.management_private_ip] #["10.10.10.4"] 
  cluster_user        = local.cluster_user            #"root"
  cluster_private_key = local.compute_private_key_content
  login_host          = local.bastion_fip
  login_user          = "vpcuser"
  login_private_key   = local.bastion_private_key_content
  command             = ["lshosts -w; lsid"]
  depends_on = [
    module.landing_zone_vsi,
    module.bootstrap
  ]
}

module "check_node_status" {
  source              = "./../../modules/null/remote_exec"
  # cluster_host        = concat(module.management_vsi[*].primary_network_interface_address, module.management_candidate_vsi[*].primary_network_interface_address)
  cluster_host        = concat(local.management_candidate_private_ips, [local.management_private_ip])
  cluster_user        = local.cluster_user
  cluster_private_key = local.compute_private_key_content
  login_host          = local.bastion_fip
  login_user          = "vpcuser"
  login_private_key   = local.bastion_private_key_content
  command             = ["lsf_daemons status"]
  depends_on = [
    module.landing_zone_vsi,
    module.bootstrap,
    module.check_cluster_status
  ]
}

# Module used to destroy the non-essential resources
module "login_fip_removal" {
  source              = "./../../modules/null/local_exec"
  count               = var.enable_fip ? 0 : 1
  region              = data.ibm_is_region.region.name
  ibmcloud_api_key    = var.ibmcloud_api_key
  trigger_resource_id = local.bastion_fip_id
  command             = "ibmcloud is ipd ${local.bastion_fip_id} -f"
  depends_on          = [module.check_cluster_status]
}

resource "null_resource" "destroy_compute_resources" {
  triggers = {
    conn_user                = local.cluster_user
    conn_host                = local.management_private_ip
    conn_private_key         = local.compute_private_key_content
    conn_bastion_host        = local.bastion_fip
    conn_bastion_private_key = local.bastion_private_key_content
  }

  # only works if fip is enabled & vpn is disabled (conn is must)
  count = var.enable_fip == true && var.enable_vpn == false ? 1 : 0

  connection {
    type                = "ssh"
    host                = self.triggers.conn_host
    user                = self.triggers.conn_user
    private_key         = self.triggers.conn_private_key
    bastion_host        = self.triggers.conn_bastion_host
    bastion_user        = "vpcuser"
    bastion_private_key = self.triggers.conn_bastion_private_key
    timeout             = "60m"
  }

  provisioner "remote-exec" {
    when       = destroy
    on_failure = fail
    inline = [
      "badmin qclose all; bkill -u all; while true; do if (bhosts -o status) | grep ok; then sleep 1m; else sleep 2m; exit 0; fi; done"
    ]
  }
}

#########################################################################################################
# validation_script_executor Module
#
# Purpose: This module is included for testing purposes.
# It provides a conditional mechanism for executing remote scripts on cluster hosts.
# The execution is triggered if the script filenames listed in TF_VALIDATION_SCRIPT_FILES are provided.
#
# Usage:
# - When scripts are listed in TF_VALIDATION_SCRIPT_FILES, the corresponding scripts
#   will be executed on the cluster hosts using remote command execution.
# - The conditional nature ensures that scripts are executed only when necessary.
#   This can be useful for various validation or maintenance tasks.
#########################################################################################################

module "validation_script_executor" {
  source = "./../../modules/null/remote_exec"
  count  = var.TF_VALIDATION_SCRIPT_FILES != null && length(var.TF_VALIDATION_SCRIPT_FILES) > 0 ? 1 : 0

  cluster_host        = [local.management_private_ip]
  cluster_user        = local.cluster_user
  cluster_private_key = local.compute_private_key_content
  login_host          = local.bastion_fip
  login_user          = "vpcuser"
  login_private_key   = local.bastion_private_key_content

  command = [
    for script_name in var.TF_VALIDATION_SCRIPT_FILES :
    file("${path.module}/examples/scripts/${script_name}")
  ]
  depends_on = [
    module.landing_zone_vsi,
    module.bootstrap,
    module.check_cluster_status
  ]
}