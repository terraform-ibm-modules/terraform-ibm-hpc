module "local_exec_script" {
  source           = "../../modules/null/local_exec_script"
  script_path      = "./scripts/check_reservation.sh"
  script_arguments = "--region ${data.ibm_is_region.region.name} --resource-group-id ${local.resource_groups["workload_rg"]} --output /tmp/hpcaas-check-reservation.log"
  script_environment = {
    IBM_CLOUD_API_KEY = nonsensitive(var.ibmcloud_api_key)
    RESERVATION_ID    = nonsensitive(var.reservation_id)
  }
}

module "landing_zone" {
  source                 = "../../modules/landing_zone"
  compute_subnets_cidr   = var.vpc_cluster_private_subnets_cidr_blocks
  cos_instance_name      = var.cos_instance_name
  enable_atracker        = var.observability_atracker_on_cos_enable
  enable_cos_integration = var.enable_cos_integration
  enable_vpc_flow_logs   = var.enable_vpc_flow_logs
  enable_vpn             = var.vpn_enabled
  key_management         = var.key_management
  kms_instance_name      = var.kms_instance_name
  kms_key_name           = var.kms_key_name
  ssh_keys               = var.bastion_ssh_keys
  bastion_subnets_cidr   = var.vpc_cluster_login_private_subnets_cidr_blocks
  network_cidr           = var.vpc_cidr
  prefix                 = var.cluster_prefix
  resource_group         = var.resource_group
  vpc                    = var.vpc_name
  subnet_id              = var.cluster_subnet_ids
  login_subnet_id        = var.login_subnet_id
  zones                  = var.zones
  no_addr_prefix         = local.no_addr_prefix
  scc_enable             = var.scc_enable
}

module "bootstrap" {
  source                        = "./../../modules/bootstrap"
  resource_group                = local.resource_groups["workload_rg"]
  prefix                        = var.cluster_prefix
  vpc_id                        = local.vpc_id
  network_cidr                  = var.vpc_name != null && length(var.cluster_subnet_ids) > 0 ? local.existing_subnet_cidrs : split(",", var.vpc_cidr)
  bastion_subnets               = local.bastion_subnets
  ssh_keys                      = var.bastion_ssh_keys
  allowed_cidr                  = local.allowed_cidr
  kms_encryption_enabled        = local.kms_encryption_enabled
  boot_volume_encryption_key    = local.boot_volume_encryption_key
  existing_kms_instance_guid    = local.existing_kms_instance_guid
  skip_iam_authorization_policy = var.skip_iam_authorization_policy
  bastion_instance_name         = var.bastion_instance_name
  bastion_instance_public_ip    = local.bastion_instance_public_ip
  bastion_security_group_id     = var.bastion_instance_name != null ? var.bastion_security_group_id : null
  ldap_server                   = var.ldap_server
}

module "generate_db_adminpassword" {
  count            = var.enable_app_center && var.app_center_high_availability ? 1 : 0
  source           = "../../modules/security/password"
  length           = 15
  special          = true
  override_special = "-_"
  min_numeric      = 1
}

module "db" {
  count             = var.enable_app_center && var.app_center_high_availability ? 1 : 0
  source            = "../../modules/database/mysql"
  resource_group_id = local.resource_groups["service_rg"]
  name              = "${var.cluster_prefix}-database"
  region            = data.ibm_is_region.region.name
  mysql_version     = local.mysql_version
  service_endpoints = local.db_service_endpoints
  adminpassword     = "db-${module.generate_db_adminpassword[0].password}" # with a prefix so we start with a letter
  members           = local.db_template[0]
  memory            = local.db_template[1]
  disks             = local.db_template[2]
  vcpu              = local.db_template[3]
}

module "landing_zone_vsi" {
  source                                           = "../../modules/landing_zone_vsi"
  resource_group                                   = local.resource_groups["workload_rg"]
  ibmcloud_api_key                                 = var.ibmcloud_api_key
  prefix                                           = var.cluster_prefix
  zones                                            = var.zones
  vpc_id                                           = local.vpc_id
  bastion_fip                                      = local.bastion_fip
  bastion_security_group_id                        = local.bastion_security_group_id
  bastion_public_key_content                       = local.bastion_public_key_content
  cluster_user                                     = local.cluster_user
  compute_private_key_content                      = local.compute_private_key_content
  bastion_private_key_content                      = local.bastion_ssh_private_key != null ? local.bastion_ssh_private_key : local.bastion_private_key_content
  compute_subnets                                  = local.compute_subnets
  compute_ssh_keys                                 = var.compute_ssh_keys
  management_image_name                            = var.management_image_name
  compute_image_name                               = var.compute_image_name
  login_image_name                                 = var.login_image_name
  dns_domain_names                                 = var.dns_domain_name
  kms_encryption_enabled                           = local.kms_encryption_enabled
  boot_volume_encryption_key                       = local.boot_volume_encryption_key
  share_path                                       = local.share_path
  hyperthreading_enabled                           = var.hyperthreading_enabled
  app_center_gui_pwd                               = var.app_center_gui_pwd
  enable_app_center                                = var.enable_app_center
  contract_id                                      = var.reservation_id
  cluster_id                                       = local.cluster_id
  management_node_count                            = var.management_node_count
  management_node_instance_type                    = var.management_node_instance_type
  file_share                                       = module.file_storage.mount_paths_excluding_first
  mount_path                                       = var.custom_file_shares
  login_node_instance_type                         = var.login_node_instance_type
  bastion_subnets                                  = local.bastion_subnets
  ssh_keys                                         = var.bastion_ssh_keys
  enable_ldap                                      = var.enable_ldap
  ldap_basedns                                     = var.ldap_basedns
  login_private_ips                                = join("", local.login_private_ips)
  ldap_vsi_profile                                 = var.ldap_vsi_profile
  ldap_admin_password                              = var.ldap_admin_password
  ldap_user_name                                   = var.ldap_user_name
  ldap_user_password                               = var.ldap_user_password
  ldap_server                                      = var.ldap_server
  ldap_vsi_osimage_name                            = var.ldap_vsi_osimage_name
  ldap_primary_ip                                  = local.ldap_private_ips
  app_center_high_availability                     = var.app_center_high_availability
  db_instance_info                                 = var.enable_app_center && var.app_center_high_availability ? module.db[0].db_instance_info : null
  storage_security_group_id                        = var.storage_security_group_id
  observability_monitoring_enable                  = var.observability_monitoring_enable
  observability_monitoring_on_compute_nodes_enable = var.observability_monitoring_on_compute_nodes_enable
  cloud_monitoring_access_key                      = var.observability_monitoring_enable ? module.cloud_monitoring_instance_creation.cloud_monitoring_access_key : ""
  cloud_monitoring_ingestion_url                   = var.observability_monitoring_enable ? module.cloud_monitoring_instance_creation.cloud_monitoring_ingestion_url : ""
  cloud_monitoring_prws_key                        = var.observability_monitoring_enable ? module.cloud_monitoring_instance_creation.cloud_monitoring_prws_key : ""
  cloud_monitoring_prws_url                        = var.observability_monitoring_enable ? module.cloud_monitoring_instance_creation.cloud_monitoring_prws_url : ""
  bastion_instance_name                            = var.bastion_instance_name
  depends_on = [
    module.local_exec_script,
    module.validate_ldap_server_connection
  ]
}

module "file_storage" {
  source             = "../../modules/file_storage"
  zone               = var.zones[0] # always the first zone
  resource_group     = local.resource_groups["workload_rg"]
  file_shares        = local.file_shares
  encryption_key_crn = local.boot_volume_encryption_key
  security_group_ids = local.compute_security_group_id
  subnet_id          = local.compute_subnet_id
  prefix             = var.cluster_prefix
}

module "dns" {
  source                 = "./../../modules/dns"
  prefix                 = var.cluster_prefix
  resource_group_id      = local.resource_groups["service_rg"]
  vpc_crn                = local.vpc_crn
  subnets_crn            = local.compute_subnets_crn
  dns_instance_id        = var.dns_instance_id
  dns_custom_resolver_id = var.dns_custom_resolver_id
  dns_domain_names       = values(var.dns_domain_name)
}

module "alb" {
  source               = "./../../modules/alb"
  bastion_subnets      = local.bastion_subnets
  resource_group_id    = local.resource_groups["workload_rg"]
  prefix               = var.cluster_prefix
  security_group_ids   = concat(local.compute_security_group_id, [local.bastion_security_group_id])
  vsi_ids              = local.vsi_management_ids
  certificate_instance = var.enable_app_center && var.app_center_high_availability ? var.existing_certificate_instance : ""
  create_load_balancer = !local.alb_created_by_api && var.app_center_high_availability && var.enable_app_center
}

module "alb_api" {
  source               = "./../../modules/alb_api"
  ibmcloud_api_key     = var.ibmcloud_api_key
  region               = data.ibm_is_region.region.name
  bastion_subnets      = local.bastion_subnets
  resource_group_id    = local.resource_groups["workload_rg"]
  prefix               = var.cluster_prefix
  security_group_ids   = concat(local.compute_security_group_id, [local.bastion_security_group_id])
  vsi_ips              = concat([local.management_private_ip], local.management_candidate_private_ips)
  certificate_instance = var.enable_app_center && var.app_center_high_availability ? var.existing_certificate_instance : ""
  create_load_balancer = local.alb_created_by_api && var.app_center_high_availability && var.enable_app_center
}

###################################################
# DNS Modules to create DNS domains and records
##################################################
module "compute_dns_records" {
  source           = "./../../modules/dns_record"
  dns_instance_id  = local.dns_instance_id
  dns_zone_id      = local.compute_dns_zone_id
  dns_records      = local.compute_dns_records
  dns_domain_names = var.dns_domain_name
}

module "compute_candidate_dns_records" {
  source           = "./../../modules/dns_record"
  dns_instance_id  = local.dns_instance_id
  dns_zone_id      = local.compute_dns_zone_id
  dns_records      = local.mgmt_candidate_dns_records
  dns_domain_names = var.dns_domain_name
}

module "login_vsi_dns_records" {
  source           = "./../../modules/dns_record"
  dns_instance_id  = local.dns_instance_id
  dns_zone_id      = local.compute_dns_zone_id
  dns_records      = local.login_vsi_dns_records
  dns_domain_names = var.dns_domain_name
}

module "ldap_vsi_dns_records" {
  source           = "./../../modules/dns_record"
  dns_instance_id  = local.dns_instance_id
  dns_zone_id      = local.compute_dns_zone_id
  dns_records      = local.ldap_vsi_dns_records
  dns_domain_names = var.dns_domain_name
}

# DNS entry needed to ALB, can be moved in dns_record module for example
resource "ibm_dns_resource_record" "pac_cname" {
  count       = var.enable_app_center && var.app_center_high_availability ? 1 : 0
  instance_id = local.dns_instance_id
  zone_id     = local.compute_dns_zone_id
  type        = "CNAME"
  name        = "pac"
  ttl         = 300
  rdata       = local.alb_hostname
}

module "compute_inventory" {
  source         = "./../../modules/inventory"
  hosts          = local.compute_hosts
  user           = local.cluster_user
  server_name    = "[HPCAASCluster]"
  inventory_path = local.compute_inventory_path
}

###################################################
# Creation of inventory files for the automation usage
##################################################
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

###################################################
# REMOTE_EXEC : Remote exec block to perform certain checks on the cluster nodes
##################################################
module "check_cluster_status" {
  source              = "./../../modules/null/remote_exec"
  cluster_host        = [local.management_private_ip] #["10.10.10.4"]
  cluster_user        = local.cluster_user            #"root"
  cluster_private_key = local.compute_private_key_content
  login_host          = local.bastion_fip
  login_user          = "ubuntu"
  login_private_key   = local.bastion_ssh_private_key != null ? local.bastion_ssh_private_key : local.bastion_private_key_content
  command             = ["lshosts -w; lsid || (sleep 5; lsid) || (sleep 15; lsid)"] # we give it more time if not ready
  depends_on = [
    module.landing_zone_vsi, # this implies vsi have been configured too
    module.bootstrap
  ]
}

module "check_node_status" {
  source              = "./../../modules/null/remote_exec"
  cluster_host        = concat(local.management_candidate_private_ips, [local.management_private_ip])
  cluster_user        = local.cluster_user
  cluster_private_key = local.compute_private_key_content
  login_host          = local.bastion_fip
  login_user          = "ubuntu"
  login_private_key   = local.bastion_ssh_private_key != null ? local.bastion_ssh_private_key : local.bastion_private_key_content
  command             = ["systemctl --no-pager -n 5 status lsfd"]
  depends_on = [
    module.landing_zone_vsi,
    module.bootstrap,
    module.check_cluster_status
  ]
}

module "validate_ldap_server_connection" {
  source            = "./../../modules/null/ldap_remote_exec"
  ldap_server       = var.ldap_server
  enable_ldap       = var.enable_ldap
  login_private_key = local.bastion_ssh_private_key != null ? local.bastion_ssh_private_key : local.bastion_private_key_content
  login_host        = local.bastion_fip
  login_user        = "ubuntu"
  depends_on        = [module.bootstrap]
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
    conn_bastion_private_key = local.bastion_ssh_private_key != null ? local.bastion_ssh_private_key : local.bastion_private_key_content
  }

  # only works if fip is enabled & vpn is disabled (conn is must)
  count = false && var.enable_fip == true && var.vpn_enabled == false ? 1 : 0

  connection {
    type                = "ssh"
    host                = self.triggers.conn_host
    user                = self.triggers.conn_user
    private_key         = self.triggers.conn_private_key
    bastion_host        = self.triggers.conn_bastion_host
    bastion_user        = "ubuntu"
    bastion_private_key = self.triggers.conn_bastion_private_key
    timeout             = "60m"
  }

  provisioner "remote-exec" {
    when       = destroy
    on_failure = fail
    inline     = [file("${path.module}/scripts/destroy_script.sh")]
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
  login_user          = "ubuntu"
  login_private_key   = local.bastion_ssh_private_key != null ? local.bastion_ssh_private_key : local.bastion_private_key_content

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

###################################################
# Observability Modules
###################################################

module "cloud_monitoring_instance_creation" {
  source                         = "../../modules/observability_instance"
  location                       = local.region
  ibmcloud_api_key               = var.ibmcloud_api_key
  rg                             = local.resource_groups["service_rg"]
  cloud_monitoring_provision     = var.observability_monitoring_enable
  observability_monitoring_plan  = var.observability_monitoring_plan
  cloud_monitoring_instance_name = "${var.cluster_prefix}-metrics"
  tags                           = ["hpc", var.cluster_prefix]
}

# Code for SCC Instance
module "scc_instance_and_profile" {
  count                   = var.scc_enable ? 1 : 0
  source                  = "./../../modules/security/scc"
  location                = var.scc_location != "" ? var.scc_location : "us-south"
  rg                      = local.resource_groups["service_rg"]
  scc_profile             = var.scc_enable ? var.scc_profile : ""
  scc_profile_version     = var.scc_profile != "" && var.scc_profile != null ? var.scc_profile_version : ""
  event_notification_plan = var.scc_event_notification_plan
  tags                    = ["hpc", var.cluster_prefix]
  prefix                  = var.cluster_prefix
  cos_bucket              = [for name in module.landing_zone.cos_buckets_names : name if strcontains(name, "scc-bucket")][0]
  cos_instance_crn        = module.landing_zone.cos_instance_crns[0]
}
