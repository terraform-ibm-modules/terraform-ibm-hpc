###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

data "ibm_is_security_group" "login_security_group" {
  count = var.login_security_group_name != null ? 1 : 0
  name  = var.login_security_group_name
}

data "ibm_is_security_group" "storage_security_group" {
  count = var.storage_security_group_name != null ? 1 : 0
  name  = var.storage_security_group_name
}

data "ibm_is_security_group" "compute_security_group" {
  count = var.compute_security_group_name != null ? 1 : 0
  name  = var.compute_security_group_name
}

data "ibm_is_security_group" "client_security_group" {
  count = var.client_security_group_name != null ? 1 : 0
  name  = var.client_security_group_name
}

data "ibm_is_security_group" "gklm_security_group" {
  count = var.gklm_security_group_name != null ? 1 : 0
  name  = var.gklm_security_group_name
}

data "ibm_is_security_group" "ldap_security_group" {
  count = var.ldap_security_group_name != null ? 1 : 0
  name  = var.ldap_security_group_name
}
