###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# This file contains the complete information on all the validations performed from the code during the generate plan process
# Validations are performed to make sure, the appropriate error messages are displayed to user in-order to provide required input parameter

locals {
  # validation for the boot volume encryption toggling.
  validate_enable_customer_managed_encryption     = anytrue([alltrue([var.kms_key_name != null, var.kms_instance_name != null]), (var.kms_key_name == null), (var.key_management != "key_protect")])
  validate_enable_customer_managed_encryption_msg = "Please make sure you are passing the kms_instance_name if you are passing kms_key_name."
  # tflint-ignore: terraform_unused_declarations
  validate_enable_customer_managed_encryption_chk = regex(
    "^${local.validate_enable_customer_managed_encryption_msg}$",
  (local.validate_enable_customer_managed_encryption ? local.validate_enable_customer_managed_encryption_msg : ""))

  # validation for the boot volume encryption toggling.
  validate_null_customer_managed_encryption     = anytrue([alltrue([var.kms_instance_name == null, var.key_management != "key_protect"]), (var.key_management == "key_protect")])
  validate_null_customer_managed_encryption_msg = "Please make sure you are setting key_management as key_protect if you are passing kms_instance_name, kms_key_name."
  # tflint-ignore: terraform_unused_declarations
  validate_null_customer_managed_encryption_chk = regex(
    "^${local.validate_null_customer_managed_encryption_msg}$",
  (local.validate_null_customer_managed_encryption ? local.validate_null_customer_managed_encryption_msg : ""))

  # validate application center gui password
  password_msg                = "Password should be at least 8 characters, must have one number, one lowercase letter, and one uppercase letter, at least one unique character. Password Should not contain username"
  validate_app_center_gui_pwd = (var.enable_app_center && can(regex("^.{8,}$", var.app_center_gui_pwd) != "") && can(regex("[0-9]{1,}", var.app_center_gui_pwd) != "") && can(regex("[a-z]{1,}", var.app_center_gui_pwd) != "") && can(regex("[A-Z]{1,}", var.app_center_gui_pwd) != "") && can(regex("[!@#$%^&*()_+=-]{1,}", var.app_center_gui_pwd) != "") && trimspace(var.app_center_gui_pwd) != "") || !var.enable_app_center
  # tflint-ignore: terraform_unused_declarations
  validate_app_center_gui_pwd_chk = regex(
    "^${local.password_msg}$",
  (local.validate_app_center_gui_pwd ? local.password_msg : ""))

  # Validate existing cluster subnet should be the subset of vpc_name entered
  validate_subnet_id_vpc_msg = "Provided cluster subnets should be within the vpc entered."
  validate_subnet_id_vpc     = anytrue([length(var.cluster_subnet_ids) == 0, length(var.cluster_subnet_ids) == 1 && var.vpc_name != null ? alltrue([for subnet_id in var.cluster_subnet_ids : contains(data.ibm_is_vpc.existing_vpc[0].subnets[*].id, subnet_id)]) : false])
  # tflint-ignore: terraform_unused_declarations
  validate_subnet_id_vpc_chk = regex("^${local.validate_subnet_id_vpc_msg}$",
  (local.validate_subnet_id_vpc ? local.validate_subnet_id_vpc_msg : ""))

  # Validate existing cluster subnet should be in the appropriate zone.
  validate_subnet_id_zone_msg = "Provided cluster subnets should be in appropriate zone."
  validate_subnet_id_zone     = anytrue([length(var.cluster_subnet_ids) == 0, length(var.cluster_subnet_ids) == 1 && var.vpc_name != null ? alltrue([data.ibm_is_subnet.existing_subnet[0].zone == var.zones[0]]) : false])
  # tflint-ignore: terraform_unused_declarations
  validate_subnet_id_zone_chk = regex("^${local.validate_subnet_id_zone_msg}$",
  (local.validate_subnet_id_zone ? local.validate_subnet_id_zone_msg : ""))

  # Validate existing login subnet should be the subset of vpc_name entered
  validate_login_subnet_id_vpc_msg = "Provided login subnet should be within the vpc entered."
  validate_login_subnet_id_vpc     = anytrue([var.login_subnet_id == null, var.login_subnet_id != null && var.vpc_name != null ? alltrue([for subnet_id in [var.login_subnet_id] : contains(data.ibm_is_vpc.existing_vpc[0].subnets[*].id, subnet_id)]) : false])
  # tflint-ignore: terraform_unused_declarations
  validate_login_subnet_id_vpc_chk = regex("^${local.validate_login_subnet_id_vpc_msg}$",
  (local.validate_login_subnet_id_vpc ? local.validate_login_subnet_id_vpc_msg : ""))

  # Validate existing login subnet should be in the appropriate zone.
  validate_login_subnet_id_zone_msg = "Provided login subnet should be in appropriate zone."
  validate_login_subnet_id_zone     = anytrue([var.login_subnet_id == null, var.login_subnet_id != null && var.vpc_name != null ? alltrue([data.ibm_is_subnet.existing_login_subnet[0].zone == var.zones[0]]) : false])
  # tflint-ignore: terraform_unused_declarations
  validate_login_subnet_id_zone_chk = regex("^${local.validate_login_subnet_id_zone_msg}$",
  (local.validate_login_subnet_id_zone ? local.validate_login_subnet_id_zone_msg : ""))

  # Contract ID validation
  #  validate_reservation_id     = length("${var.cluster_id}${var.reservation_id}") > 129 ? false : true
  #  validate_reservation_id_msg = "The length of reservation_id and cluster_id combination should not exceed 128 characters."
  #  # tflint-ignore: terraform_unused_declarations
  #  validate_reservation_id_chk = regex(
  #    "^${local.validate_reservation_id_msg}$",
  #  (local.validate_reservation_id ? local.validate_reservation_id_msg : ""))

  validate_reservation_id_api     = var.solution == "hpc" ? local.valid_status_code && local.reservation_id_found : true
  validate_reservation_id_api_msg = "The provided reservation id doesn't have a valid reservation or the reservation id is not on the same account as HPC deployment."
  # tflint-ignore: terraform_unused_declarations
  validate_reservation_id_api_chk = regex(
    "^${local.validate_reservation_id_api_msg}$",
  (local.validate_reservation_id_api ? local.validate_reservation_id_api_msg : ""))

  validate_worker_count     = var.solution == "lsf" ? local.total_worker_node_count <= var.worker_node_max_count : true
  validate_worker_error_msg = "If the solution is set as lsf, the worker min count cannot be greater than worker max count."
  # tflint-ignore: terraform_unused_declarations
  validate_worker_count_chk = regex(
    "^${local.validate_worker_error_msg}$",
  (local.validate_worker_count ? local.validate_worker_error_msg : ""))

  validate_lsf_solution           = var.solution == "lsf" ? var.ibm_customer_number != null : true
  validate_lsf_solution_error_msg = "If the solution is set as LSF, then the ibm customer number cannot be set as null."
  # tflint-ignore: terraform_unused_declarations
  validate_lsf_solution_chk = regex(
    "^${local.validate_lsf_solution_error_msg}$",
  (local.validate_lsf_solution ? local.validate_lsf_solution_error_msg : ""))

  validate_icn_number       = var.solution == "lsf" ? can(regex("^[0-9A-Za-z]*([0-9A-Za-z]+,[0-9A-Za-z]+)*$", var.ibm_customer_number)) : true
  validate_icn_number_error = "The IBM customer number input value cannot have special characters."
  # tflint-ignore: terraform_unused_declarations
  validate_icn_number_chk = regex(
    "^${local.validate_icn_number_error}$",
  (local.validate_icn_number ? local.validate_icn_number_error : ""))


  # Validate custom fileshare
  # Construct a list of Share size(GB) and IOPS range(IOPS)from values provided in https://cloud.ibm.com/docs/vpc?topic=vpc-file-storage-profiles&interface=ui#dp2-profile
  # List values [[sharesize_start,sharesize_end,min_iops,max_iops], [..]....]
  custom_fileshare_iops_range = [[10, 39, 100, 1000], [40, 79, 100, 2000], [80, 99, 100, 4000], [100, 499, 100, 6000], [500, 999, 100, 10000], [1000, 1999, 100, 20000], [2000, 3999, 200, 40000], [4000, 7999, 300, 40000], [8000, 15999, 500, 64000], [16000, 32000, 2000, 96000]]
  # List with input iops value, min and max iops for the input share size.
  size_iops_lst              = [for values in var.custom_file_shares : [for list_val in local.custom_fileshare_iops_range : [values.size != null ? (values.iops != null ? (values.size >= list_val[0] && values.size <= list_val[1] ? values.iops : null) : null) : null, list_val[2], list_val[3]] if values.size != null]]
  validate_custom_file_share = alltrue([for iops in local.size_iops_lst : (length(iops) > 0 ? (iops[0][0] != null ? (iops[0][0] >= iops[0][1] && iops[0][0] <= iops[0][2]) : true) : true)])
  # Validate the input iops falls inside the range.
  # validate_custom_file_share     = alltrue([for iops in local.size_iops_lst : iops[0][0] >= iops[0][1] && iops[0][0] <= iops[0][2]])
  validate_custom_file_share_msg = "Provided iops value is not valid for given file share size. Please refer 'File Storage for VPC profiles' page in ibm cloud docs for a valid iops and file share size combination."
  # tflint-ignore: terraform_unused_declarations
  validate_custom_file_share_chk = regex(
    "^${local.validate_custom_file_share_msg}$",
  (local.validate_custom_file_share ? local.validate_custom_file_share_msg : ""))

  # LDAP base DNS Validation
  validate_ldap_basedns = (var.enable_ldap && trimspace(var.ldap_basedns) != "") || !var.enable_ldap
  ldap_basedns_msg      = "If LDAP is enabled, then the base DNS should not be empty or null. Need a valid domain name."
  # tflint-ignore: terraform_unused_declarations
  validate_ldap_basedns_chk = regex(
    "^${local.ldap_basedns_msg}$",
  (local.validate_ldap_basedns ? local.ldap_basedns_msg : ""))

  # LDAP base existing LDAP server
  validate_ldap_server = (var.enable_ldap && trimspace(var.ldap_server) != "") || !var.enable_ldap
  ldap_server_msg      = "IP of existing LDAP server. If none given a new ldap server will be created. It should not be empty."
  # tflint-ignore: terraform_unused_declarations
  validate_ldap_server_chk = regex(
    "^${local.ldap_server_msg}$",
  (local.validate_ldap_server ? local.ldap_server_msg : ""))

  # Existing LDAP server cert validation
  validate_ldap_server_cert = (
    (trimspace(var.ldap_server) != "" && trimspace(var.ldap_server_cert) != "" && trimspace(var.ldap_server_cert) != "null") ||
    trimspace(var.ldap_server) == "null" ||
    !var.enable_ldap
  )
  ldap_server_cert_msg = "Provide the current LDAP server certificate. This is required if 'ldap_server' is not set to 'null'; otherwise, the LDAP configuration will not succeed."
  # tflint-ignore: terraform_unused_declarations
  validate_ldap_server_cert_chk = regex(
    "^${local.ldap_server_cert_msg}$",
    local.validate_ldap_server_cert ? local.ldap_server_cert_msg : ""
  )

  # LDAP Admin Password Validation
  validate_ldap_adm_pwd = var.enable_ldap && var.ldap_server == "null" ? (length(var.ldap_admin_password) >= 8 && length(var.ldap_admin_password) <= 20 && can(regex("^(.*[0-9]){2}.*$", var.ldap_admin_password))) && can(regex("^(.*[A-Z]){1}.*$", var.ldap_admin_password)) && can(regex("^(.*[a-z]){1}.*$", var.ldap_admin_password)) && can(regex("^.*[~@_+:].*$", var.ldap_admin_password)) && can(regex("^[^!#$%^&*()=}{\\[\\]|\\\"';?.<,>-]+$", var.ldap_admin_password)) : local.ldap_server_status
  ldap_adm_password_msg = "Password that is used for LDAP admin. The password must contain at least 8 characters and at most 20 characters. For a strong password, at least three alphabetic characters are required, with at least one uppercase and one lowercase letter. Two numbers, and at least one special character. Make sure that the password doesn't include the username."
  # tflint-ignore: terraform_unused_declarations
  validate_ldap_adm_pwd_chk = regex(
    "^${local.ldap_adm_password_msg}$",
  (local.validate_ldap_adm_pwd ? local.ldap_adm_password_msg : ""))

  # LDAP User Validation
  validate_ldap_usr = var.enable_ldap && var.ldap_server == "null" ? (length(var.ldap_user_name) >= 4 && length(var.ldap_user_name) <= 32 && var.ldap_user_name != "" && can(regex("^[a-zA-Z0-9_-]*$", var.ldap_user_name)) && trimspace(var.ldap_user_name) != "") : local.ldap_server_status
  ldap_usr_msg      = "The input for 'ldap_user_name' is considered invalid. The username must be within the range of 4 to 32 characters and may only include letters, numbers, hyphens, and underscores. Spaces are not permitted."
  # tflint-ignore: terraform_unused_declarations
  validate_ldap_usr_chk = regex(
    "^${local.ldap_usr_msg}$",
  (local.validate_ldap_usr ? local.ldap_usr_msg : ""))

  # LDAP User Password Validation
  validate_ldap_usr_pwd = var.enable_ldap && var.ldap_server == "null" ? (length(var.ldap_user_password) >= 8 && length(var.ldap_user_password) <= 20 && can(regex("^(.*[0-9]){2}.*$", var.ldap_user_password))) && can(regex("^(.*[A-Z]){1}.*$", var.ldap_user_password)) && can(regex("^(.*[a-z]){1}.*$", var.ldap_user_password)) && can(regex("^.*[~@_+:].*$", var.ldap_user_password)) && can(regex("^[^!#$%^&*()=}{\\[\\]|\\\"';?.<,>-]+$", var.ldap_user_password)) : local.ldap_server_status
  ldap_usr_password_msg = "Password that is used for LDAP user. The password must contain at least 8 characters and at most 20 characters. For a strong password, at least three alphabetic characters are required, with at least one uppercase and one lowercase letter. Two numbers, and at least one special character. Make sure that the password doesn't include the username."
  # tflint-ignore: terraform_unused_declarations
  validate_ldap_usr_pwd_chk = regex(
    "^${local.ldap_usr_password_msg}$",
  (local.validate_ldap_usr_pwd ? local.ldap_usr_password_msg : ""))

  # Validate existing subnet public gateways
  validate_subnet_name_pg_msg = "Provided existing cluster_subnet_ids should have public gateway attached."
  validate_subnet_name_pg     = anytrue([length(var.cluster_subnet_ids) == 0, length(var.cluster_subnet_ids) == 1 && var.vpc_name != null ? (data.ibm_is_subnet.existing_subnet[0].public_gateway != "") : false])
  # tflint-ignore: terraform_unused_declarations
  validate_subnet_name_pg_chk = regex("^${local.validate_subnet_name_pg_msg}$",
  (local.validate_subnet_name_pg ? local.validate_subnet_name_pg_msg : ""))

  # Validate existing vpc public gateways
  validate_existing_vpc_pgw_msg = "Provided existing vpc should have the public gateways created in the provided zones."
  validate_existing_vpc_pgw     = anytrue([(var.vpc_name == null), alltrue([var.vpc_name != null, length(var.cluster_subnet_ids) == 1]), alltrue([var.vpc_name != null, length(var.cluster_subnet_ids) == 0, var.login_subnet_id == null, length(local.zone_1_pgw_ids) > 0])])
  # tflint-ignore: terraform_unused_declarations
  validate_existing_vpc_pgw_chk = regex("^${local.validate_existing_vpc_pgw_msg}$",
  (local.validate_existing_vpc_pgw ? local.validate_existing_vpc_pgw_msg : ""))

  # Validate in case of existing subnets provide both login_subnet_id and cluster_subnet_ids.
  validate_login_subnet_id_msg = "In case of existing subnets provide both login_subnet_id and cluster_subnet_ids."
  validate_login_subnet_id     = anytrue([alltrue([length(var.cluster_subnet_ids) == 0, var.login_subnet_id == null]), alltrue([length(var.cluster_subnet_ids) != 0, var.login_subnet_id != null])])
  # tflint-ignore: terraform_unused_declarations
  validate_login_subnet_id_chk = regex("^${local.validate_login_subnet_id_msg}$",
  (local.validate_login_subnet_id ? local.validate_login_subnet_id_msg : ""))

  # Validate the subnet_id user input value
  validate_subnet_id_msg = "If the cluster_subnet_ids are provided, the user should also provide the vpc_name."
  validate_subnet_id     = anytrue([var.vpc_name != null && length(var.cluster_subnet_ids) > 0, length(var.cluster_subnet_ids) == 0])
  # tflint-ignore: terraform_unused_declarations
  validate_subnet_id_chk = regex("^${local.validate_subnet_id_msg}$",
  (local.validate_subnet_id ? local.validate_subnet_id_msg : ""))

  # Management node count validation when Application Center is in High Availability
  validate_management_node_count = (var.enable_app_center && var.app_center_high_availability && var.management_node_count >= 2) || !var.app_center_high_availability || !var.enable_app_center
  management_node_count_msg      = "When the Application Center is installed in High Availability, at least two management nodes must be installed."
  # tflint-ignore: terraform_unused_declarations
  validate_management_node_count_chk = regex(
    "^${local.management_node_count_msg}$",
  (local.validate_management_node_count ? local.management_node_count_msg : ""))

  # IBM Cloud Application load Balancer CRN validation
  validate_alb_crn     = (var.enable_app_center && var.app_center_high_availability) && can(regex("^crn:v1:bluemix:public:secrets-manager:[a-zA-Z\\-]+:[a-zA-Z0-9\\-]+\\/[a-zA-Z0-9\\-]+:[a-fA-F0-9\\-]+:secret:[a-fA-F0-9\\-]+$", var.app_center_existing_certificate_instance)) || !var.app_center_high_availability || !var.enable_app_center
  alb_crn_template_msg = "When app_center_high_availability is enable/set as true, The Application Center will be configured for high availability and requires a Application Load Balancer Front End listener to use a certificate CRN value stored in the Secret Manager. Provide the valid 'existing_certificate_instance' to configure the Application load balancer."
  # tflint-ignore: terraform_unused_declarations
  validate_alb_crn_chk = regex(
    "^${local.alb_crn_template_msg}$",
  (local.validate_alb_crn ? local.alb_crn_template_msg : ""))

  # Validate the dns_custom_resolver_id should not be given in case of new vpc case
  validate_custom_resolver_id_msg = "If it is the new vpc deployment, do not provide existing dns_custom_resolver_id as that will impact the name resolution of the cluster."
  validate_custom_resolver_id     = anytrue([var.vpc_name != null, var.vpc_name == null && var.dns_custom_resolver_id == null])
  # tflint-ignore: terraform_unused_declarations
  validate_custom_resolver_id_chk = regex("^${local.validate_custom_resolver_id_msg}$",
  (local.validate_custom_resolver_id ? local.validate_custom_resolver_id_msg : ""))

  validate_reservation_id_new_msg = "Provided reservation id cannot be set as empty if the provided solution is set as hpc.."
  validate_reservation_id_logic   = var.solution == "hpc" ? var.reservation_id != null : true
  # tflint-ignore: terraform_unused_declarations
  validate_reservation_id_chk_new = regex("^${local.validate_reservation_id_new_msg}$",
  (local.validate_reservation_id_logic ? local.validate_reservation_id_new_msg : ""))

  # IBM Cloud Monitoring validation
  validate_observability_monitoring_enable_compute_nodes = (var.observability_monitoring_enable && var.observability_monitoring_on_compute_nodes_enable) || (var.observability_monitoring_enable && var.observability_monitoring_on_compute_nodes_enable == false) || (var.observability_monitoring_enable == false && var.observability_monitoring_on_compute_nodes_enable == false)
  observability_monitoring_enable_compute_nodes_msg      = "Please enable also IBM Cloud Monitoring to ingest metrics from Compute nodes"
  # tflint-ignore: terraform_unused_declarations
  observability_monitoring_enable_compute_nodes_chk = regex(
    "^${local.observability_monitoring_enable_compute_nodes_msg}$",
  (local.validate_observability_monitoring_enable_compute_nodes ? local.observability_monitoring_enable_compute_nodes_msg : ""))

  # Existing Bastion validation
  validate_existing_bastion     = var.existing_bastion_instance_name != null ? (var.existing_bastion_instance_public_ip != null && var.existing_bastion_security_group_id != null && var.existing_bastion_ssh_private_key != null) : local.bastion_instance_status
  validate_existing_bastion_msg = "If bastion_instance_name is not null, then bastion_instance_public_ip, bastion_security_group_id, and bastion_ssh_private_key should not be null."
  # tflint-ignore: terraform_unused_declarations
  validate_existing_bastion_chk = regex(
    "^${local.validate_existing_bastion_msg}$",
  (local.validate_existing_bastion ? local.validate_existing_bastion_msg : ""))

  # Existing Storage security group validation
  validate_existing_storage_sg     = length([for share in var.custom_file_shares : { mount_path = share.mount_path, nfs_share = share.nfs_share } if share.nfs_share != null && share.nfs_share != ""]) > 0 ? var.storage_security_group_id != null ? true : false : true
  validate_existing_storage_sg_msg = "Storage security group ID cannot be null when NFS share mount path is provided under cluster_file_shares variable."
  # tflint-ignore: terraform_unused_declarations
  validate_existing_storage_sg_chk = regex(
    "^${local.validate_existing_storage_sg_msg}$",
  (local.validate_existing_storage_sg ? local.validate_existing_storage_sg_msg : ""))
}
