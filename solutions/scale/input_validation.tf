###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################
# This file contains the complete information on all the validations performed from the code during the generate plan process
# Validations are performed to make sure, the appropriate error messages are displayed to user in-order to provide required input parameter

locals {
  validate_ibm_customer_number           = trim(var.ibm_customer_number) != ""
  validate_ibm_customer_number_error_msg = "IBM customer number cannot be empty."

  # tflint-ignore: terraform_unused_declarations
  validate_ibm_customer_number_chk = regex(
    "^${local.validate_ibm_customer_number_error_msg}$",
    (local.validate_ibm_customer_number ? local.validate_ibm_customer_number_error_msg : "")
  )
}  