data "ibm_is_security_group" "storage_security_group" {
  count = var.vpc_name != null && var.storage_security_group_name != null ? 1 : 0
  name  = var.storage_security_group_name
}

data "ibm_is_security_group" "compute_security_group" {
  count = var.vpc_name != null && var.compute_security_group_name != null ? 1 : 0
  name  = var.compute_security_group_name
}

data "ibm_is_security_group" "gklm_security_group" {
  count = var.vpc_name != null && var.gklm_security_group_name != null ? 1 : 0
  name  = var.gklm_security_group_name
}

data "ibm_is_security_group" "ldap_security_group" {
  count = var.vpc_name != null && var.ldap_security_group_name != null ? 1 : 0
  name  = var.ldap_security_group_name
}

data "ibm_is_security_group" "client_security_group" {
  count = var.vpc_name != null && var.client_security_group_name != null ? 1 : 0
  name  = var.client_security_group_name
}

data "ibm_is_security_group" "login_security_group" {
  count = var.vpc_name != null && var.login_security_group_name != null ? 1 : 0
  name  = var.login_security_group_name
}
