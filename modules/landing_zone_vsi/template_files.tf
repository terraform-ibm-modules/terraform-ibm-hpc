data "template_file" "management_user_data" {
  template = file("${path.module}/templates/management_user_data.tpl")
  vars = {
    management_node_count       = var.management_node_count
    rc_cidr_block               = local.compute_subnets[0].cidr
    cluster_prefix              = var.prefix
    cluster_private_key_content = local.enable_management ? module.compute_key[0].private_key_content : ""
    cluster_public_key_content  = local.enable_management ? module.compute_key[0].public_key_content : ""
    hyperthreading              = var.hyperthreading_enabled
    network_interface           = local.vsi_interfaces[0]
    dns_domain                  = var.dns_domain_names["compute"]
    mount_path                  = var.share_path
    enable_ldap                 = var.enable_ldap
    ldap_server_ip              = local.ldap_server
    ldap_server_cert            = local.ldap_server_cert
    ldap_basedns                = var.enable_ldap == true ? var.ldap_basedns : "null"
    login_ip_address            = var.login_private_ips
  }
}

data "template_file" "login_user_data" {
  template = file("${path.module}/templates/login_user_data.tpl")
  vars = {
    network_interface           = local.vsi_interfaces[0]
    dns_domain                  = var.dns_domain_names["compute"]
    cluster_private_key_content = local.enable_management ? module.compute_key[0].private_key_content : ""
    cluster_public_key_content  = local.enable_management ? module.compute_key[0].public_key_content : ""
    mount_path                  = var.share_path
    custom_mount_paths          = join(" ", concat(local.vpc_file_share[*]["mount_path"], local.nfs_file_share[*]["mount_path"]))
    custom_file_shares          = join(" ", concat([for file_share in var.file_share : file_share], local.nfs_file_share[*]["nfs_share"]))
    enable_ldap                 = var.enable_ldap
    rc_cidr_block               = local.bastion_subnets[0].cidr
    cluster_prefix              = var.prefix
    rc_cidr_block_1             = local.compute_subnets[0].cidr
    hyperthreading              = var.hyperthreading_enabled
    ldap_server_ip              = local.ldap_server
    ldap_basedns                = var.enable_ldap == true ? var.ldap_basedns : "null"
  }
}

data "template_file" "ldap_user_data" {
  count    = var.enable_ldap == true ? 1 : 0
  template = file("${path.module}/templates/ldap_user_data.tpl")
  vars = {
    ssh_public_key_content = local.enable_management ? module.compute_key[0].public_key_content : ""
    ldap_basedns           = var.ldap_basedns
    ldap_admin_password    = var.ldap_admin_password
    cluster_prefix         = var.prefix
    ldap_user              = var.ldap_user_name
    ldap_user_password     = var.ldap_user_password
    mount_path             = var.share_path
    dns_domain             = var.dns_domain_names["compute"]
  }
}

data "template_file" "worker_user_data" {
  template = file("${path.module}/templates/static_worker_user_data.tpl")
  vars = {
    network_interface                                = local.vsi_interfaces[0]
    dns_domain                                       = var.dns_domain_names["compute"]
    cluster_private_key_content                      = local.enable_management ? module.compute_key[0].private_key_content : ""
    cluster_public_key_content                       = local.enable_management ? module.compute_key[0].public_key_content : ""
    mount_path                                       = var.share_path
    custom_mount_paths                               = join(" ", concat(local.vpc_file_share[*]["mount_path"], local.nfs_file_share[*]["mount_path"]))
    custom_file_shares                               = join(" ", concat([for file_share in var.file_share : file_share], local.nfs_file_share[*]["nfs_share"]))
    enable_ldap                                      = var.enable_ldap
    rc_cidr_block                                    = local.compute_subnets[0].cidr
    cluster_prefix                                   = var.prefix
    hyperthreading                                   = var.hyperthreading_enabled
    ldap_server_ip                                   = local.ldap_server
    ldap_basedns                                     = var.enable_ldap == true ? var.ldap_basedns : "null"
    cluster_name                                     = var.cluster_id
    management_hostname                              = local.management_hostname
    observability_monitoring_enable                  = var.observability_monitoring_enable
    observability_monitoring_on_compute_nodes_enable = var.observability_monitoring_on_compute_nodes_enable
    cloud_monitoring_access_key                      = var.cloud_monitoring_access_key
    cloud_monitoring_ingestion_url                   = var.cloud_monitoring_ingestion_url
    cloud_logs_ingress_private_endpoint              = var.cloud_logs_ingress_private_endpoint
    observability_logs_enable_for_compute            = var.observability_logs_enable_for_compute
    VPC_APIKEY_VALUE                                 = var.ibmcloud_api_key
  }
}

data "template_file" "management_values" {
  template = file("${path.module}/configuration_steps/management_values.tpl")
  vars = {
    bastion_public_key_content    = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    vpc_apikey_value              = var.ibmcloud_api_key
    resource_records_apikey_value = var.ibmcloud_api_key
    management_node_count         = var.management_node_count
    api_endpoint_us_east          = local.us_east
    api_endpoint_eu_de            = local.eu_de
    api_endpoint_us_south         = local.us_south
    image_id                      = local.compute_image_from_data ? data.ibm_is_image.compute[0].id : local.new_compute_image_id
    subnet_id                     = local.compute_subnets[0].crn
    security_group_id             = module.compute_sg[0].security_group_id
    sshkey_id                     = join(",", local.compute_ssh_keys)
    region_name                   = data.ibm_is_region.region.name
    zone_name                     = var.zones[0]
    vpc_id                        = var.vpc_id
    rc_cidr_block                 = local.compute_subnets[0].cidr
    rc_max_num                    = local.rc_max_num
    rc_rg                         = var.resource_group
    cluster_name                  = var.cluster_id
    ce_project_guid               = var.ce_project_guid
    cluster_prefix                = var.prefix
    cluster_private_key_content   = local.enable_management ? module.compute_key[0].private_key_content : ""
    cluster_public_key_content    = local.enable_management ? module.compute_key[0].public_key_content : ""
    hyperthreading                = var.hyperthreading_enabled
    network_interface             = local.vsi_interfaces[0]
    dns_domain                    = var.dns_domain_names["compute"]
    mount_path                    = var.share_path
    custom_mount_paths            = join(" ", concat(local.vpc_file_share[*]["mount_path"], local.nfs_file_share[*]["mount_path"]))
    custom_file_shares            = join(" ", concat([for file_share in var.file_share : file_share], local.nfs_file_share[*]["nfs_share"]))
    contract_id                   = var.solution == "hpc" ? var.contract_id : ""
    enable_app_center             = var.enable_app_center
    app_center_gui_pwd            = var.app_center_gui_pwd
    enable_ldap                   = var.enable_ldap
    ldap_server_ip                = local.ldap_server
    ldap_server_cert              = local.ldap_server_cert
    ldap_server_hostname          = length(local.ldap_hostnames) > 0 ? local.ldap_hostnames[0] : "null"
    ldap_basedns                  = var.enable_ldap == true ? var.ldap_basedns : "null"
    bootdrive_crn                 = var.boot_volume_encryption_key == null ? "" : var.boot_volume_encryption_key
    management_ip                 = local.management_private_ip
    management_hostname           = local.management_hostname
    management_cand_ips           = join(",", local.management_candidate_private_ips)
    management_cand_hostnames     = join(",", local.management_candidate_hostnames)
    login_ip                      = local.login_private_ips[0]
    login_hostname                = local.login_hostnames[0]
    # PAC High Availability
    app_center_high_availability = var.app_center_high_availability
    db_adminuser                 = var.enable_app_center && var.app_center_high_availability ? var.db_instance_info.admin_user : ""
    db_adminpassword             = var.enable_app_center && var.app_center_high_availability ? var.db_admin_password : ""
    db_hostname                  = var.enable_app_center && var.app_center_high_availability ? var.db_instance_info.hostname : ""
    db_port                      = var.enable_app_center && var.app_center_high_availability ? var.db_instance_info.port : ""
    db_certificate               = var.enable_app_center && var.app_center_high_availability ? var.db_instance_info.certificate : ""
    db_name                      = var.enable_app_center && var.app_center_high_availability ? local.db_name : ""
    db_user                      = var.enable_app_center && var.app_center_high_availability ? local.db_user : ""
    db_password                  = var.enable_app_center && var.app_center_high_availability ? module.generate_db_password[0].password : ""
    # Observability
    observability_monitoring_enable                  = var.observability_monitoring_enable
    observability_monitoring_on_compute_nodes_enable = var.observability_monitoring_on_compute_nodes_enable
    cloud_monitoring_access_key                      = var.cloud_monitoring_access_key
    cloud_monitoring_ingestion_url                   = var.cloud_monitoring_ingestion_url
    cloud_monitoring_prws_key                        = var.cloud_monitoring_prws_key
    cloud_monitoring_prws_url                        = var.cloud_monitoring_prws_url
    cloud_logs_ingress_private_endpoint              = var.cloud_logs_ingress_private_endpoint
    observability_logs_enable_for_management         = var.observability_logs_enable_for_management
    observability_logs_enable_for_compute            = var.observability_logs_enable_for_compute
    solution                                         = var.solution
    rc_ncores                                        = local.ncores
    rc_ncpus                                         = local.ncpus
    rc_mem_in_mb                                     = local.mem_in_mb
    rc_profile                                       = local.rc_profile
  }
}
