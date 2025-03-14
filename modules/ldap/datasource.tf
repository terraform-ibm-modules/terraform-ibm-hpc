data "ibm_is_image" "ldap_vsi_image" {
    count = var.ldap_basedns != null && var.ldap_server == "null" ? 1 : 0
    name  = var.ldap_vsi_osimage_name
}

data "ibm_is_ssh_key" "compute" {
  for_each = toset(var.compute_ssh_keys)
  name     = each.key
}