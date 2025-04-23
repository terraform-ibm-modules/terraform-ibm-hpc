data "ibm_resource_group" "existing_resource_group" {
  name = var.existing_resource_group
}

data "ibm_is_image" "management_stock_image" {
  count = length(var.management_instances)
  name  = var.management_instances[count.index]["image"]
}

data "ibm_is_image" "management" {
  name  = var.management_instances[0]["image"]
  count = local.image_mapping_entry_found ? 0 : 1
}

data "ibm_is_image" "compute" {
  name  = var.static_compute_instances[0]["image"]
  count = local.compute_image_found_in_map ? 1 : 0
}

# TODO: Verify distinct profiles
/*
data "ibm_is_instance_profile" "management" {
  name = var.management_profile
}

data "ibm_is_instance_profile" "compute" {
  name = var.compute_profile
}

data "ibm_is_instance_profile" "protocol" {
  name = var.protocol_profile
}
*/

data "ibm_is_image" "client" {
  count = length(var.client_instances)
  name  = var.client_instances[count.index]["image"]
}

data "ibm_is_image" "compute_stock_image" {
  count = length(var.static_compute_instances)
  name  = var.static_compute_instances[count.index]["image"]
}

data "ibm_is_image" "storage" {
  count = length(var.storage_instances)
  name  = var.storage_instances[count.index]["image"]
}

# data "ibm_is_image" "protocol" {
#   count = length(var.protocol_instances)
#   name  = var.protocol_instances[count.index]["image"]
# }


data "ibm_is_ssh_key" "client" {
  for_each = toset(var.client_ssh_keys)
  name     = each.key
}

data "ibm_is_ssh_key" "compute" {
  for_each = toset(var.compute_ssh_keys)
  name     = each.key
}

data "ibm_is_ssh_key" "storage" {
  for_each = toset(var.storage_ssh_keys)
  name     = each.key
}

data "ibm_is_instance_profile" "storage" {
  count = length(var.storage_instances)
  name  = var.storage_instances[count.index]["profile"]
}

data "ibm_is_instance_profile" "storage_tie_instance" {
  count = length(var.storage_instances)
  name  = var.storage_instances[count.index]["profile"]
}

data "ibm_is_ssh_key" "gklm" {
  for_each = toset(var.gklm_instance_key_pair)
  name     = each.key
}

data "ibm_is_ssh_key" "ldap" {
  for_each = toset(var.ldap_instance_key_pair)
  name     = each.key
}

data "ibm_is_image" "ldap_vsi_image" {
  count = var.enable_ldap != null && var.ldap_server == null ? 1 : 0
  name  = var.ldap_instances[count.index]["image"]
}

data "ibm_is_image" "afm" {
  count = length(var.afm_instances)
  name  = var.afm_instances[count.index]["image"]
}

data "ibm_is_image" "gklm" {
  count = length(var.gklm_instances)
  name  = var.gklm_instances[count.index]["image"]
}
