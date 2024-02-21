# data "template_file" "login_user_data" {
#   template = file("${path.module}/templates/login_user_data.tpl")
#   vars = {
#     bastion_public_key_content = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
#     login_public_key_content   = local.enable_login ? module.compute_key[0].public_key_content : ""
#     login_private_key_content  = local.enable_login ? module.compute_key[0].private_key_content : ""
#     login_interfaces           = var.storage_type == "scratch" ? local.vsi_interfaces[0] : local.bms_interfaces[0]
#     login_dns_domain           = var.dns_domain_names["compute"]
#   }
# }

data "template_file" "management_user_data" {
  template = file("${path.module}/templates/management_user_data.tpl")
  vars = {
    bastion_public_key_content    = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    vpc_apikey_value              = var.ibmcloud_api_key
    resource_records_apikey_value = var.ibmcloud_api_key
    management_node_count         = var.management_node_count
    # management_node_count         = jsonencode(var.management_instances)
    api_endpoint_us_east          = local.us-east
    api_endpoint_eu_de            = local.eu-de
    image_id                      = local.compute_image_mapping_entry_found ? local.new_compute_image_id : data.ibm_is_image.compute[0].id
    #subnet_id                     = local.subnet_list[0].crn
    #subnet_id_2                   = local.subnet_list[1].crn
    #subnet_id                     = local.compute_subnets[0].id
    #subnet_id_2                   = local.compute_subnets[1].id
    subnet_id                   = local.compute_subnets[0].crn
    subnet_id_2                 = local.compute_subnets[1].crn
    security_group_id           = module.compute_sg[0].security_group_id
    sshkey_id                   = join(",", local.compute_ssh_keys)
    region_name                 = data.ibm_is_region.region.name
    zone_name                   = var.zones[0]
    zone_name_2                 = var.zones[1]
    vpc_id                      = var.vpc_id
    rc_cidr_block               = local.compute_subnets[0].cidr
    rc_cidr_block_2             = local.compute_subnets[1].cidr
    rc_maxNum                   = local.rc_maxNum
    rc_rg                       = var.resource_group
    cluster_name                = var.cluster_id
    cluster_prefix              = var.prefix
    cluster_private_key_content = local.enable_management ? module.compute_key[0].private_key_content : ""
    cluster_public_key_content  = local.enable_management ? module.compute_key[0].public_key_content : ""
    hyperthreading              = var.hyperthreading_enabled
    network_interface           = local.vsi_interfaces[0]
    dns_domain                  = var.dns_domain_names["compute"]
    mount_path                  = var.share_path
    custom_file_shares            = join(" ", [for file_share in var.file_share : file_share])
    #custom_mount_paths            = join(" ", [for mount_path in var.mount_path : mount_path])
    custom_mount_paths = join(" ", [for mount_path_obj in var.mount_path : mount_path_obj.mount_path])
    contract_id        = var.contract_id
    enable_app_center  = var.enable_app_center
    app_center_gui_pwd = var.app_center_gui_pwd
    enable_ldap                   = var.enable_ldap
    ldap_server_ip                = local.ldap_server
    #ldap_basedns                  = var.ldap_basedns != null ? "\"${var.ldap_basedns}\"" : "null"
    ldap_basedns                  = var.enable_ldap == true ? var.ldap_basedns : "null"
    login_ip_address              = var.login_private_ips
    bootdrive_crn                 = var.boot_volume_encryption_key == null ? "" : var.boot_volume_encryption_key
    # PAC High Availability
    enable_high_availability      = var.enable_high_availability
    db_adminuser                  = var.enable_app_center && var.enable_high_availability ?  var.db_instance_info.adminuser : ""
    db_adminpassword              = var.enable_app_center && var.enable_high_availability ?  var.db_instance_info.adminpassword : ""
    db_hostname                   = var.enable_app_center && var.enable_high_availability ?  var.db_instance_info.hostname : ""
    db_port                       = var.enable_app_center && var.enable_high_availability ?  var.db_instance_info.port : ""
    db_certificate                = var.enable_app_center && var.enable_high_availability ?  var.db_instance_info.certificate : ""
    db_name                       = var.enable_app_center && var.enable_high_availability ?  local.db_name : ""
    db_user                       = var.enable_app_center && var.enable_high_availability ?  local.db_user : ""
    db_password                   = var.enable_app_center && var.enable_high_availability ?  module.generate_db_password[0].password : ""
  }
}

data "template_file" "compute_user_data" {
  template = file("${path.module}/templates/compute_user_data.tpl")
  vars = {
    bastion_public_key_content  = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
    compute_public_key_content  = local.enable_compute ? module.compute_key[0].public_key_content : ""
    compute_private_key_content = local.enable_compute ? module.compute_key[0].private_key_content : ""
    compute_interfaces          = var.storage_type == "scratch" ? local.vsi_interfaces[0] : local.bms_interfaces[0]
    compute_dns_domain          = var.dns_domain_names["compute"]
    # TODO: Fix me
    # dynamic_compute_instances = var.dynamic_compute_instances == null ? "" : ""
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
    enable_ldap                 = var.enable_ldap
    rc_cidr_block               = local.bastion_subnets[0].cidr
    cluster_prefix              = var.prefix
    rc_cidr_block_1             = local.compute_subnets[0].cidr
    rc_cidr_block_2             = local.compute_subnets[1].cidr
    hyperthreading              = var.hyperthreading_enabled
    ldap_server_ip              = local.ldap_server
    ldap_basedns                = var.enable_ldap == true ? var.ldap_basedns : "null"
  }
}

data "template_file" "ldap_user_data" {
  count = var.enable_ldap == true ? 1 : 0
  template = file("${path.module}/templates/ldap_user_data.tpl")
  vars = {
    ssh_public_key_content = local.enable_management ? module.compute_key[0].public_key_content : ""
    ldap_basedns           = var.ldap_basedns
    ldap_admin_password    = var.ldap_admin_password
    cluster_prefix         = var.prefix
    ldap_user              = var.ldap_user_name
    ldap_user_password     = var.ldap_user_password
    dns_domain             = var.dns_domain_names["compute"]
  }
}

# data "template_file" "storage_user_data" {
#   template = file("${path.module}/templates/storage_user_data.tpl")
#   vars = {
#     bastion_public_key_content  = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
#     storage_public_key_content  = local.enable_storage ? module.storage_key[0].public_key_content : ""
#     storage_private_key_content = local.enable_storage ? module.storage_key[0].private_key_content : ""
#     storage_interfaces          = var.storage_type == "scratch" ? local.vsi_interfaces[0] : local.bms_interfaces[0]
#     storage_dns_domain          = var.dns_domain_names["storage"]
#   }
# }

# data "template_file" "protocol_user_data" {
#   template = file("${path.module}/templates/protocol_user_data.tpl")
#   vars = {
#     bastion_public_key_content  = var.bastion_public_key_content != null ? var.bastion_public_key_content : ""
#     storage_public_key_content  = local.enable_protocol ? module.storage_key[0].public_key_content : ""
#     storage_private_key_content = local.enable_protocol ? module.storage_key[0].private_key_content : ""
#     storage_interfaces          = var.storage_type == "scratch" ? local.vsi_interfaces[0] : local.bms_interfaces[0]
#     protocol_interfaces         = var.storage_type == "scratch" ? local.vsi_interfaces[1] : local.bms_interfaces[1]
#     storage_dns_domain          = var.dns_domain_names["storage"]
#     protocol_dns_domain         = var.dns_domain_names["protocol"]
#   }
# }
