###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################
# This file contains the complete information on all the validations performed from the code during the generate plan process
# Validations are performed to make sure, the appropriate error messages are displayed to user in-order to provide required input parameter

locals {
  icn_cnd = (var.storage_type != "evaluation" && var.ibm_customer_number == null) ? false : true
  icn_msg = "The IBM customer number input value can't be empty when storage_type is not evaluation."
  icn_chk = regex("^${local.icn_msg}$", (local.icn_cnd ? local.icn_msg : ""))
}