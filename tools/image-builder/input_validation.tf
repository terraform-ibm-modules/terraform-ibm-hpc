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

  # Validate existing packer subnet should be the subset of vpc_name entered
  validate_subnet_id_vpc_msg = "Provided packer subnet should be within the vpc entered."
  validate_subnet_id_vpc     = anytrue([var.subnet_id == null, var.subnet_id != null && var.vpc_name != null ? alltrue([for subnet_id in [var.subnet_id] : contains(data.ibm_is_vpc.existing_vpc[0].subnets[*].id, subnet_id)]) : false])
  # tflint-ignore: terraform_unused_declarations
  validate_subnet_id_vpc_chk = regex("^${local.validate_subnet_id_vpc_msg}$",
  (local.validate_subnet_id_vpc ? local.validate_subnet_id_vpc_msg : ""))

  # Validate existing packer subnet should be in the appropriate zone.
  validate_subnet_id_zone_msg = "Provided packer subnet should be in appropriate zone."
  validate_subnet_id_zone     = anytrue([var.subnet_id == null, var.subnet_id != null && var.vpc_name != null ? alltrue([data.ibm_is_subnet.existing_subnet[0].zone == var.zones[0]]) : false])
  # tflint-ignore: terraform_unused_declarations
  validate_subnet_id_zone_chk = regex("^${local.validate_subnet_id_zone_msg}$",
  (local.validate_subnet_id_zone ? local.validate_subnet_id_zone_msg : ""))

  # Validate existing packer subnet public gateways
  validate_subnet_name_pg_msg = "Provided existing packer subnet should have public gateway attached."
  validate_subnet_name_pg     = anytrue([var.subnet_id == null, var.subnet_id != null && var.vpc_name != null ? (data.ibm_is_subnet.existing_subnet[0].public_gateway != "") : false])
  # tflint-ignore: terraform_unused_declarations
  validate_subnet_name_pg_chk = regex("^${local.validate_subnet_name_pg_msg}$",
  (local.validate_subnet_name_pg ? local.validate_subnet_name_pg_msg : ""))

  # Validate existing vpc public gateways
  validate_existing_vpc_pgw_msg = "Provided existing vpc should have the public gateways created in the provided zones."
  validate_existing_vpc_pgw     = anytrue([(var.vpc_name == null), alltrue([var.vpc_name != null, var.subnet_id != null]), alltrue([var.vpc_name != null, var.subnet_id == null, length(local.zone_1_pgw_ids) > 0])])
  # tflint-ignore: terraform_unused_declarations
  validate_existing_vpc_pgw_chk = regex("^${local.validate_existing_vpc_pgw_msg}$",
  (local.validate_existing_vpc_pgw ? local.validate_existing_vpc_pgw_msg : ""))

  # Validate the subnet_id user input value
  validate_subnet_id_msg = "If the packer subnet_id is provided, the user should also provide the vpc_name."
  validate_subnet_id     = anytrue([var.vpc_name != null && var.subnet_id != null, var.subnet_id == null])
  # tflint-ignore: terraform_unused_declarations
  validate_subnet_id_chk = regex("^${local.validate_subnet_id_msg}$",
  (local.validate_subnet_id ? local.validate_subnet_id_msg : ""))

  # Validate security_group_id user input value
  validate_security_group_id_msg = "If existing security_group_id is provided, the user should also specify vpc_name that has that security group ID."
  validate_security_group_id     = anytrue([var.vpc_name != null && var.security_group_id != "", var.security_group_id == ""])
  # tflint-ignore: terraform_unused_declarations
  validate_security_group_id_chk = regex("^${local.validate_security_group_id_msg}$",
  (local.validate_security_group_id ? local.validate_security_group_id_msg : ""))

}
