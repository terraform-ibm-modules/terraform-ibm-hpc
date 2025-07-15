# data "ibm_resource_group" "existing_resource_group" {
#   name = var.existing_resource_group
# }

data "ibm_is_image" "management_stock_image" {
  count = local.image_mapping_entry_found ? 0 : length(var.management_instances)
  name  = var.management_instances[count.index]["image"]
}

# data "ibm_is_image" "management" {
#   name  = var.management_instances[0]["image"]
#   count = local.image_mapping_entry_found ? 0 : 1
# }

# data "ibm_is_image" "compute" {
#   name  = var.static_compute_instances[0]["image"]
#   count = local.compute_image_found_in_map ? 1 : 0
# }

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
  count = local.compute_image_found_in_map ? 0 : length(var.static_compute_instances)
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


data "ibm_is_ssh_key" "ssh_keys" {
  for_each = toset(var.ssh_keys)
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
  count = var.enable_ldap != null && var.ldap_server == "null" ? 1 : 0
  name  = var.ldap_instances[count.index]["image"]
}

data "ibm_is_image" "afm" {
  count = length(var.afm_instances)
  name  = var.afm_instances[count.index]["image"]
}

data "ibm_is_image" "gklm" {
  count = var.scale_encryption_enabled && var.scale_encryption_type == "gklm" && length(var.gklm_instances) > 0 ? 1 : 0
  name  = var.gklm_instances[count.index]["image"]
}

data "ibm_is_image" "login_vsi_image" {
  count = local.login_image_found_in_map ? 0 : 1
  name  = var.login_instance[count.index]["image"]
}

data "ibm_is_dedicated_host_profiles" "profiles" {
  count = var.enable_dedicated_host ? 1 : 0
}
