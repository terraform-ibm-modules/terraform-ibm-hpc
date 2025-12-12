###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################
# This file contains the complete information on all the validations performed from the code during the generate plan process
# Validations are performed to make sure, the appropriate error messages are displayed to user in-order to provide required input parameter

locals {
  icn_cnd = (var.storage_type != "evaluation" && var.ibm_customer_number == null) ? false : true
  icn_msg = "The IBM customer number input value can't be empty when storage_type is not evaluation."
  # tflint-ignore: terraform_unused_declarations
  icn_chk = regex("^${local.icn_msg}$", (local.icn_cnd ? local.icn_msg : ""))
}

locals {
  total_compute_instance_count  = sum(var.compute_instances[*]["count"])
  total_storage_instance_count  = var.storage_type == "baremetal" ? sum(var.storage_baremetal_server[*]["count"]) : sum(var.storage_instances[*]["count"])
  total_client_instance_count   = sum(var.client_instances[*]["count"])
  total_gklm_instance_count     = sum(var.gklm_instances[*]["count"])
  total_protocol_instance_count = sum(var.protocol_instances[*]["count"])

  storage_sg_rules = flatten([for remote in data.ibm_is_security_group.storage_security_group[*].rules[*] : remote[*].remote])
  compute_sg_rules = flatten([for remote in data.ibm_is_security_group.compute_security_group[*].rules[*] : remote[*].remote])
  gklm_sg_rules    = flatten([for remote in data.ibm_is_security_group.gklm_security_group[*].rules[*] : remote[*].remote])
  ldap_sg_rules    = flatten([for remote in data.ibm_is_security_group.ldap_security_group[*].rules[*] : remote[*].remote])
  client_sg_rules  = flatten([for remote in data.ibm_is_security_group.client_security_group[*].rules[*] : remote[*].remote])
  #  bastion_sg_rules = flatten([for remote in data.ibm_is_security_group.login_security_group[*].rules[*] : remote[*].remote])

  gklm_condition    = var.enable_sg_validation == true && local.total_gklm_instance_count > 0 && var.scale_encryption_enabled == true && var.scale_encryption_type == "gklm" && var.gklm_security_group_name != null
  strg_condition    = var.enable_sg_validation == true && local.total_storage_instance_count > 0 && var.storage_security_group_name != null
  clnt_condition    = var.enable_sg_validation == true && local.total_client_instance_count > 0 && var.client_security_group_name != null
  comp_condition    = var.enable_sg_validation == true && local.total_compute_instance_count > 0 && var.compute_security_group_name != null
  ldap_condition    = var.enable_sg_validation == true && var.enable_ldap == true && var.ldap_security_group_name != null
  bastion_condition = var.enable_sg_validation == true && var.login_security_group_name != null

  # Storage Security group validation
  validate_strg_sg_in_strg_sg = local.strg_condition ? contains(local.storage_sg_rules, tolist(data.ibm_is_security_group.storage_security_group[*].id)[0]) : true
  strg_sg_in_strg_sg_msg      = "The Storage security group does not include the storage security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_strg_sg_in_strg_sg_chk = var.storage_security_group_name != null ? regex("^${local.strg_sg_in_strg_sg_msg}$", (local.validate_strg_sg_in_strg_sg ? local.strg_sg_in_strg_sg_msg : "")) : true

  validate_comp_sg_in_strg_sg = local.comp_condition ? contains(local.storage_sg_rules, tolist(data.ibm_is_security_group.compute_security_group[*].id)[0]) : true
  comp_sg_in_strg_sg_msg      = "The Storage security group does not include the compute security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_comp_sg_in_strg_sg_chk = var.storage_security_group_name != null ? regex("^${local.comp_sg_in_strg_sg_msg}$", (local.validate_comp_sg_in_strg_sg ? local.comp_sg_in_strg_sg_msg : "")) : true

  validate_client_sg_in_strg_sg = local.clnt_condition ? contains(local.storage_sg_rules, tolist(data.ibm_is_security_group.client_security_group[*].id)[0]) : true
  client_sg_in_strg_sg_msg      = "The Storage security group does not include the client security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_client_sg_in_strg_sg_chk = var.storage_security_group_name != null ? regex("^${local.client_sg_in_strg_sg_msg}$", (local.validate_client_sg_in_strg_sg ? local.client_sg_in_strg_sg_msg : "")) : true

  validate_gklm_sg_in_strg_sg = local.gklm_condition ? contains(local.storage_sg_rules, tolist(data.ibm_is_security_group.gklm_security_group[*].id)[0]) : true
  gklm_sg_in_strg_sg_msg      = "The Storage security group does not include the gklm security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_gklm_sg_in_strg_sg_chk = var.storage_security_group_name != null ? regex("^${local.gklm_sg_in_strg_sg_msg}$", (local.validate_gklm_sg_in_strg_sg ? local.gklm_sg_in_strg_sg_msg : "")) : true

  validate_ldap_sg_in_strg_sg = local.ldap_condition ? contains(local.storage_sg_rules, tolist(data.ibm_is_security_group.ldap_security_group[*].id)[0]) : true
  ldap_sg_in_strg_sg_msg      = "The Storage security group does not include the ldap security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_ldap_sg_in_strg_sg_chk = var.storage_security_group_name != null ? regex("^${local.ldap_sg_in_strg_sg_msg}$", (local.validate_ldap_sg_in_strg_sg ? local.ldap_sg_in_strg_sg_msg : "")) : true

  validate_bastion_in_strg_sg = local.bastion_condition ? contains(local.storage_sg_rules, tolist(data.ibm_is_security_group.login_security_group[*].id)[0]) : true
  bastion_sg_in_strg_sg_msg   = "The Storage security group does not include the bastion security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_bastion_in_strg_sg_chk = var.storage_security_group_name != null ? regex("^${local.bastion_sg_in_strg_sg_msg}$", (local.validate_bastion_in_strg_sg ? local.bastion_sg_in_strg_sg_msg : "")) : true


  # Compute Security group validation
  validate_strg_sg_in_comp_sg = local.strg_condition ? contains(local.compute_sg_rules, tolist(data.ibm_is_security_group.storage_security_group[*].id)[0]) : true
  strg_sg_in_comp_sg_msg      = "The Compute security group does not include the storage security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_strg_sg_in_comp_sg_chk = var.compute_security_group_name != null ? regex("^${local.strg_sg_in_comp_sg_msg}$", (local.validate_strg_sg_in_comp_sg ? local.strg_sg_in_comp_sg_msg : "")) : true

  validate_comp_sg_in_comp_sg = local.comp_condition ? contains(local.compute_sg_rules, tolist(data.ibm_is_security_group.compute_security_group[*].id)[0]) : true
  comp_sg_in_comp_sg_msg      = "The Compute security group does not include the compute security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_comp_sg_in_comp_sg_chk = var.compute_security_group_name != null ? regex("^${local.comp_sg_in_comp_sg_msg}$", (local.validate_comp_sg_in_comp_sg ? local.comp_sg_in_comp_sg_msg : "")) : true

  validate_client_sg_in_comp_sg = local.clnt_condition ? contains(local.compute_sg_rules, tolist(data.ibm_is_security_group.client_security_group[*].id)[0]) : true
  client_sg_in_comp_sg_msg      = "The Compute security group does not include the client security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_client_sg_in_comp_sg_chk = var.compute_security_group_name != null ? regex("^${local.client_sg_in_comp_sg_msg}$", (local.validate_client_sg_in_comp_sg ? local.client_sg_in_comp_sg_msg : "")) : true

  validate_gklm_sg_in_comp_sg = local.gklm_condition ? contains(local.compute_sg_rules, tolist(data.ibm_is_security_group.gklm_security_group[*].id)[0]) : true
  gklm_sg_in_comp_sg_msg      = "The Compute security group does not include the gklm security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_gklm_sg_in_comp_sg_chk = var.compute_security_group_name != null ? regex("^${local.gklm_sg_in_comp_sg_msg}$", (local.validate_gklm_sg_in_comp_sg ? local.gklm_sg_in_comp_sg_msg : "")) : true

  validate_ldap_sg_in_comp_sg = local.ldap_condition ? contains(local.compute_sg_rules, tolist(data.ibm_is_security_group.ldap_security_group[*].id)[0]) : true
  ldap_sg_in_comp_sg_msg      = "The Compute security group does not include the ldap security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_ldap_sg_in_comp_sg_chk = var.compute_security_group_name != null ? regex("^${local.ldap_sg_in_comp_sg_msg}$", (local.validate_ldap_sg_in_comp_sg ? local.ldap_sg_in_comp_sg_msg : "")) : true

  validate_bastion_sg_in_comp_sg = local.bastion_condition ? contains(local.compute_sg_rules, tolist(data.ibm_is_security_group.login_security_group[*].id)[0]) : true
  bastion_sg_in_comp_sg_msg      = "The Compute security group does not include the bastion security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_bastion_sg_in_comp_sg_chk = var.compute_security_group_name != null ? regex("^${local.bastion_sg_in_comp_sg_msg}$", (local.validate_bastion_sg_in_comp_sg ? local.bastion_sg_in_comp_sg_msg : "")) : true


  # GKLM Security group validation
  validate_strg_sg_in_gklm_sg = local.strg_condition ? contains(local.gklm_sg_rules, tolist(data.ibm_is_security_group.storage_security_group[*].id)[0]) : true
  strg_sg_in_gklm_sg_msg      = "The GKLM security group does not include the storage security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_strg_sg_in_gklm_sg_chk = var.gklm_security_group_name != null ? regex("^${local.strg_sg_in_gklm_sg_msg}$", (local.validate_strg_sg_in_gklm_sg ? local.strg_sg_in_gklm_sg_msg : "")) : true

  validate_comp_sg_in_gklm_sg = local.comp_condition ? contains(local.gklm_sg_rules, tolist(data.ibm_is_security_group.compute_security_group[*].id)[0]) : true
  comp_sg_in_gklm_sg_msg      = "The GKLM security group does not include the compute security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_comp_sg_in_gklm_sg_chk = var.gklm_security_group_name != null ? regex("^${local.comp_sg_in_gklm_sg_msg}$", (local.validate_comp_sg_in_gklm_sg ? local.comp_sg_in_gklm_sg_msg : "")) : true

  validate_gklm_sg_in_gklm_sg = local.gklm_condition ? contains(local.gklm_sg_rules, tolist(data.ibm_is_security_group.gklm_security_group[*].id)[0]) : true
  gklm_sg_in_gklm_sg_msg      = "The GKLM security group does not include the GKLM security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_gklm_sg_in_gklm_sg_chk = var.gklm_security_group_name != null ? regex("^${local.gklm_sg_in_gklm_sg_msg}$", (local.validate_gklm_sg_in_gklm_sg ? local.gklm_sg_in_gklm_sg_msg : "")) : true

  validate_client_sg_in_gklm_sg = local.clnt_condition ? contains(local.gklm_sg_rules, tolist(data.ibm_is_security_group.client_security_group[*].id)[0]) : true
  client_sg_in_gklm_sg_msg      = "The GKLM security group does not include the client security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_client_sg_in_gklm_sg_chk = var.gklm_security_group_name != null ? regex("^${local.client_sg_in_gklm_sg_msg}$", (local.validate_client_sg_in_gklm_sg ? local.client_sg_in_gklm_sg_msg : "")) : true

  validate_ldap_sg_in_gklm_sg = local.ldap_condition ? contains(local.gklm_sg_rules, tolist(data.ibm_is_security_group.ldap_security_group[*].id)[0]) : true
  ldap_sg_in_gklm_sg_msg      = "The GKLM security group does not include the ldap security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_ldap_sg_in_gklm_sg_chk = var.gklm_security_group_name != null ? regex("^${local.ldap_sg_in_gklm_sg_msg}$", (local.validate_ldap_sg_in_gklm_sg ? local.ldap_sg_in_gklm_sg_msg : "")) : true

  validate_bastion_sg_in_gklm_sg = local.bastion_condition ? contains(local.gklm_sg_rules, tolist(data.ibm_is_security_group.login_security_group[*].id)[0]) : true
  bastion_sg_in_gklm_sg_msg      = "The GKLM security group does not include the bastion security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_bastion_sg_in_gklm_sg_chk = var.gklm_security_group_name != null ? regex("^${local.bastion_sg_in_gklm_sg_msg}$", (local.validate_bastion_sg_in_gklm_sg ? local.bastion_sg_in_gklm_sg_msg : "")) : true


  # LDAP Security group validation
  validate_strg_sg_in_ldap_sg = local.strg_condition ? contains(local.ldap_sg_rules, tolist(data.ibm_is_security_group.storage_security_group[*].id)[0]) : true
  strg_sg_in_ldap_sg_msg      = "The LDAP security group does not include the storage security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_strg_sg_in_ldap_sg_chk = var.ldap_security_group_name != null ? regex("^${local.strg_sg_in_ldap_sg_msg}$", (local.validate_strg_sg_in_ldap_sg ? local.strg_sg_in_ldap_sg_msg : "")) : true

  validate_comp_sg_in_ldap_sg = local.comp_condition ? contains(local.ldap_sg_rules, tolist(data.ibm_is_security_group.compute_security_group[*].id)[0]) : true
  comp_sg_in_ldap_sg_msg      = "The LDAP security group does not include the compute security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_comp_sg_in_ldap_sg_chk = var.ldap_security_group_name != null ? regex("^${local.comp_sg_in_ldap_sg_msg}$", (local.validate_comp_sg_in_ldap_sg ? local.comp_sg_in_ldap_sg_msg : "")) : true

  validate_ldap_sg_in_ldap_sg = local.ldap_condition ? contains(local.ldap_sg_rules, tolist(data.ibm_is_security_group.ldap_security_group[*].id)[0]) : true
  ldap_sg_in_ldap_sg_msg      = "The LDAP security group does not include the LDAP security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_ldap_sg_in_ldap_sg_chk = var.ldap_security_group_name != null ? regex("^${local.ldap_sg_in_ldap_sg_msg}$", (local.validate_ldap_sg_in_ldap_sg ? local.ldap_sg_in_ldap_sg_msg : "")) : true

  validate_gklm_sg_in_ldap_sg = local.gklm_condition ? contains(local.ldap_sg_rules, tolist(data.ibm_is_security_group.gklm_security_group[*].id)[0]) : true
  gklm_sg_in_ldap_sg_msg      = "The LDAP security group does not include the GKLM security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_gklm_sg_in_ldap_sg_chk = var.ldap_security_group_name != null ? regex("^${local.gklm_sg_in_ldap_sg_msg}$", (local.validate_gklm_sg_in_ldap_sg ? local.gklm_sg_in_ldap_sg_msg : "")) : true

  validate_client_sg_in_ldap_sg = local.clnt_condition ? contains(local.ldap_sg_rules, tolist(data.ibm_is_security_group.client_security_group[*].id)[0]) : true
  client_sg_in_ldap_sg_msg      = "The LDAP security group does not include the client security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_client_sg_in_ldap_sg_chk = var.ldap_security_group_name != null ? regex("^${local.client_sg_in_ldap_sg_msg}$", (local.validate_client_sg_in_ldap_sg ? local.client_sg_in_ldap_sg_msg : "")) : true

  validate_bastion_sg_in_ldap_sg = local.bastion_condition ? contains(local.ldap_sg_rules, tolist(data.ibm_is_security_group.login_security_group[*].id)[0]) : true
  bastion_sg_in_ldap_sg_msg      = "The LDAP security group does not include the bastion security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_bastion_sg_in_ldap_sg_chk = var.ldap_security_group_name != null ? regex("^${local.bastion_sg_in_ldap_sg_msg}$", (local.validate_bastion_sg_in_ldap_sg ? local.bastion_sg_in_ldap_sg_msg : "")) : true

  # Client Security group validation
  validate_strg_sg_in_client_sg = local.strg_condition ? contains(local.client_sg_rules, tolist(data.ibm_is_security_group.storage_security_group[*].id)[0]) : true
  strg_sg_in_client_sg_msg      = "The Client security group does not include the storage security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_strg_sg_in_client_sg_chk = var.client_security_group_name != null ? regex("^${local.strg_sg_in_client_sg_msg}$", (local.validate_strg_sg_in_client_sg ? local.strg_sg_in_client_sg_msg : "")) : true

  validate_comp_sg_in_client_sg = local.comp_condition ? contains(local.client_sg_rules, tolist(data.ibm_is_security_group.compute_security_group[*].id)[0]) : true
  comp_sg_in_client_sg_msg      = "The Client security group does not include the compute security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_comp_sg_in_client_sg_chk = var.client_security_group_name != null ? regex("^${local.comp_sg_in_client_sg_msg}$", (local.validate_comp_sg_in_client_sg ? local.comp_sg_in_client_sg_msg : "")) : true

  validate_ldap_sg_in_client_sg = local.ldap_condition ? contains(local.client_sg_rules, tolist(data.ibm_is_security_group.ldap_security_group[*].id)[0]) : true
  ldap_sg_in_client_sg_msg      = "The Client security group does not include the LDAP security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_ldap_sg_in_client_sg_chk = var.client_security_group_name != null ? regex("^${local.ldap_sg_in_client_sg_msg}$", (local.validate_ldap_sg_in_client_sg ? local.ldap_sg_in_client_sg_msg : "")) : true

  validate_gklm_sg_in_client_sg = local.gklm_condition ? contains(local.client_sg_rules, tolist(data.ibm_is_security_group.gklm_security_group[*].id)[0]) : true
  gklm_sg_in_client_sg_msg      = "The Client security group does not include the GKLM security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_gklm_sg_in_client_sg_chk = var.client_security_group_name != null ? regex("^${local.gklm_sg_in_client_sg_msg}$", (local.validate_gklm_sg_in_client_sg ? local.gklm_sg_in_client_sg_msg : "")) : true

  validate_client_sg_in_client_sg = local.clnt_condition ? contains(local.client_sg_rules, tolist(data.ibm_is_security_group.client_security_group[*].id)[0]) : true
  client_sg_in_client_sg_msg      = "The Client security group does not include the client security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_client_sg_in_client_sg_chk = var.client_security_group_name != null ? regex("^${local.client_sg_in_client_sg_msg}$", (local.validate_client_sg_in_client_sg ? local.client_sg_in_client_sg_msg : "")) : true

  validate_bastion_sg_in_client_sg = local.bastion_condition ? contains(local.client_sg_rules, tolist(data.ibm_is_security_group.login_security_group[*].id)[0]) : true
  bastion_sg_in_client_sg_msg      = "The Client security group does not include the bastion security group as a rule."
  # tflint-ignore: terraform_unused_declarations
  validate_bastion_sg_in_client_sg_chk = var.client_security_group_name != null ? regex("^${local.bastion_sg_in_client_sg_msg}$", (local.validate_bastion_sg_in_client_sg ? local.bastion_sg_in_client_sg_msg : "")) : true
}

locals {
  # Subnet ID validation for existing VPC with instances count greater than 0
  validate_subnet_id_ext_vpc_msg = "When 'subnet_id' is passed and any of the 'instance_count' values are greater than 0, you must provide the respective 'subnet_id' or set 'instance_count' to 0."
  validate_subnet_id_ext_vpc = alltrue([
    var.vpc_name != null && (var.storage_subnet_id != null || var.compute_subnet_id != null || var.protocol_subnet_id != null || var.client_subnet_id != null || var.login_subnet_id != null) ?
    ((local.total_storage_instance_count > 0 && var.storage_subnet_id != null) ? true : ((local.total_storage_instance_count == 0 && var.storage_subnet_id == null) ? true : false)) &&
    ((local.total_client_instance_count > 0 && var.client_subnet_id != null) ? true : ((local.total_client_instance_count == 0 && var.client_subnet_id == null) ? true : false)) &&
    ((local.total_protocol_instance_count > 0 && var.protocol_subnet_id != null) ? true : ((local.total_protocol_instance_count == 0 && var.protocol_subnet_id == null) ? true : false)) &&
    ((local.total_compute_instance_count > 0 && var.compute_subnet_id != null) ? true : ((local.total_compute_instance_count == 0 && var.compute_subnet_id == null) ? true : false)) &&
    ((var.login_subnet_id != null) ? true : false)
  : true])
  # tflint-ignore: terraform_unused_declarations
  validate_subnet_id_ext_vpc_chk = regex("^${local.validate_subnet_id_ext_vpc_msg}$",
  (local.validate_subnet_id_ext_vpc ? local.validate_subnet_id_ext_vpc_msg : ""))
}
