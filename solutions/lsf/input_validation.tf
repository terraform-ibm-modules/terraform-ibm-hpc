###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################
# This file contains the complete information on all the validations performed from the code during the generate plan process
# Validations are performed to make sure, the appropriate error messages are displayed to user in-order to provide required input parameter

locals {

  # Validate existing login subnet should be in the appropriate zone.
  validate_login_subnet_id_zone_msg = "Provided login subnet should be in appropriate zone."
  validate_login_subnet_id_zone     = anytrue([var.login_subnet_id == null, var.login_subnet_id != null && var.vpc_name != null ? alltrue([data.ibm_is_subnet.existing_login_subnets[0].zone == var.zones[0]]) : false])
  # tflint-ignore: terraform_unused_declarations
  validate_login_subnet_id_zone_chk = regex("^${local.validate_login_subnet_id_zone_msg}$",
  (local.validate_login_subnet_id_zone ? local.validate_login_subnet_id_zone_msg : ""))

  # Validate existing login subnet should be the subset of vpc_name entered
  validate_login_subnet_id_vpc_msg = "Provided login subnet should be within the vpc entered."
  validate_login_subnet_id_vpc     = anytrue([var.login_subnet_id == null, var.login_subnet_id != null && var.vpc_name != null ? alltrue([for subnet_id in [var.login_subnet_id] : contains(data.ibm_is_vpc.existing_vpc[0].subnets[*].id, subnet_id)]) : false])
  # tflint-ignore: terraform_unused_declarations
  validate_login_subnet_id_vpc_chk = regex("^${local.validate_login_subnet_id_vpc_msg}$",
  (local.validate_login_subnet_id_vpc ? local.validate_login_subnet_id_vpc_msg : ""))

  # Validate existing subnet public gateways
  validate_subnet_name_pg_msg = "Provided existing compute_subnet_id should have public gateway attached."
  validate_subnet_name_pg     = anytrue([var.compute_subnet_id == null, var.compute_subnet_id != null && var.vpc_name != null ? (data.ibm_is_subnet.existing_compute_subnets[0].public_gateway != "") : false])
  # tflint-ignore: terraform_unused_declarations
  validate_subnet_name_pg_chk = regex("^${local.validate_subnet_name_pg_msg}$",
  (local.validate_subnet_name_pg ? local.validate_subnet_name_pg_msg : ""))

  # Validate existing cluster subnet should be in the appropriate zone.
  validate_subnet_id_zone_msg = "Provided cluster subnets should be in appropriate zone."
  validate_subnet_id_zone     = anytrue([var.compute_subnet_id == null, var.compute_subnet_id != null && var.vpc_name != null ? alltrue([data.ibm_is_subnet.existing_compute_subnets[0].zone == var.zones[0]]) : false])
  # tflint-ignore: terraform_unused_declarations
  validate_subnet_id_zone_chk = regex("^${local.validate_subnet_id_zone_msg}$",
  (local.validate_subnet_id_zone ? local.validate_subnet_id_zone_msg : ""))

  # Validate existing cluster subnet should be the subset of vpc_name entered
  validate_compute_subnet_id_vpc_msg = "Provided cluster subnet should be within the vpc entered."
  validate_compute_subnet_id_vpc     = anytrue([var.compute_subnet_id == null, var.compute_subnet_id != null && var.vpc_name != null ? alltrue([for subnet_id in [var.compute_subnet_id] : contains(data.ibm_is_vpc.existing_vpc[0].subnets[*].id, subnet_id)]) : false])
  # tflint-ignore: terraform_unused_declarations
  validate_subnet_id_vpc_chk = regex("^${local.validate_compute_subnet_id_vpc_msg}$",
  (local.validate_compute_subnet_id_vpc ? local.validate_compute_subnet_id_vpc_msg : ""))

  # Validate existing vpc public gateways
  validate_existing_vpc_pgw_msg = "Provided existing vpc should have the public gateways created in the provided zones."
  validate_existing_vpc_pgw     = anytrue([(var.vpc_name == null), alltrue([var.vpc_name != null, var.compute_subnet_id != null]), alltrue([var.vpc_name != null, var.compute_subnet_id == null, var.login_subnet_id == null, length(local.zone_1_pgw_ids) > 0])])
  # tflint-ignore: terraform_unused_declarations
  validate_existing_vpc_pgw_chk = regex("^${local.validate_existing_vpc_pgw_msg}$",
  (local.validate_existing_vpc_pgw ? local.validate_existing_vpc_pgw_msg : ""))
}

locals {
  vpc_id               = var.vpc_name != null && var.compute_subnet_id == null && var.login_subnet_id == null ? data.ibm_is_vpc.existing_vpc[0].id : null
  public_gateways_list = var.vpc_name != null && var.compute_subnet_id == null && var.login_subnet_id == null ? data.ibm_is_public_gateways.public_gateways[0].public_gateways : []
  zone_1_pgw_ids       = var.vpc_name != null && var.compute_subnet_id == null && var.login_subnet_id == null ? [for gateway in local.public_gateways_list : gateway.id if gateway.vpc == local.vpc_id && gateway.zone == var.zones[0]] : []
}

locals {

  password_validation_required = var.enable_webservice || var.enable_appcenter

  ###########################################################################
  # Password presence validation
  ###########################################################################

  validate_webservice_password_msg = "webservice_appcenter_password must be provided when enable_webservice or enable_appcenter is true."

  validate_webservice_password = (
    !local.password_validation_required ||
    var.webservice_appcenter_password != ""
  )

  # tflint-ignore: terraform_unused_declarations
  validate_webservice_password_chk = regex(
    "^$",
    local.validate_webservice_password ? "" : local.validate_webservice_password_msg
  )


  ###########################################################################
  # Password complexity validation
  ###########################################################################

  validate_password_complexity_msg = "Password must be at least 15 characters long and include uppercase, lowercase, number and special character (!@#$%^&*()_+=-). Spaces are not allowed."

  validate_password_complexity = (
    !local.password_validation_required ||
    (
      length(var.webservice_appcenter_password) >= 15 &&
      can(regex("[0-9]", var.webservice_appcenter_password)) &&
      can(regex("[a-z]", var.webservice_appcenter_password)) &&
      can(regex("[A-Z]", var.webservice_appcenter_password)) &&
      can(regex("[!@#$%^&*()_+=-]", var.webservice_appcenter_password)) &&
      !can(regex("\\s", var.webservice_appcenter_password))
    )
  )

  # tflint-ignore: terraform_unused_declarations
  validate_password_complexity_chk = regex(
    "^$",
    local.validate_password_complexity ? "" : local.validate_password_complexity_msg
  )

}
