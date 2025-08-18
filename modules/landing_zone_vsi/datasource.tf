data "ibm_is_image" "management_stock_image" {
  count = local.image_mapping_entry_found ? 0 : length(var.management_instances)
  name  = var.management_instances[count.index]["image"]
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
  count = var.scheduler == "Scale" ? length(var.client_instances) : 0
  name  = var.client_instances[count.index]["image"]
}

# data "ibm_is_image" "compute_stock_image" {
#   count = local.compute_image_found_in_map ? 0 : length(var.static_compute_instances)
#   name  = var.static_compute_instances[count.index]["image"]
# }

data "ibm_is_image" "compute_stock_image" {
  count = var.scheduler == "LSF" && !local.compute_image_found_in_map ? length(var.static_compute_instances) : 0
  name  = var.static_compute_instances[count.index]["image"]
}

data "ibm_is_image" "scale_compute_stock_image" {
  count = (
    var.scheduler == "Scale" &&
    !local.scale_storage_image_found_in_map
  ) ? length(var.static_compute_instances) : 0
  name = var.static_compute_instances[count.index]["image"]
}

data "ibm_is_instance_profile" "compute_profile" {
  count = length(var.static_compute_instances)
  name  = var.static_compute_instances[count.index]["profile"]
}

data "ibm_is_image" "storage" {
  count = (
    var.scheduler == "Scale" &&
    !local.scale_storage_image_found_in_map
  ) ? length(var.storage_instances) : 0
  name = var.storage_instances[count.index]["image"]
}

data "ibm_is_image" "baremetal_storage" {
  count = (
    var.scheduler == "Scale" &&
    !local.scale_storage_image_found_in_map
  ) ? length(var.storage_servers) : 0
  name = var.storage_servers[count.index]["image"]
}

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

data "ibm_is_image" "ldap_vsi_image" {
  count = var.enable_ldap != null && var.ldap_server == "null" ? 1 : 0
  name  = var.ldap_instances[count.index]["image"]
}

data "ibm_is_image" "afm" {
  count = var.scheduler == "Scale" ? (
    (!local.scale_storage_image_found_in_map)
    ? length(var.afm_instances)
    : 0
  ) : 0
  name = var.afm_instances[count.index]["image"]
}

data "ibm_is_image" "protocol" {
  count = var.scheduler == "Scale" ? (
    (!local.scale_storage_image_found_in_map)
    ? length(var.protocol_instances)
    : 0
  ) : 0
  name = var.protocol_instances[count.index]["image"]
}


data "ibm_is_image" "gklm" {
  count = var.scheduler == "Scale" ? (var.scale_encryption_enabled && var.scale_encryption_type == "gklm" && length(var.gklm_instances) > 0 && !local.scale_encryption_image_mapping_entry_found ? 1 : 0) : 0
  name  = var.gklm_instances[count.index]["image"]
}

data "ibm_is_image" "login_vsi_image" {
  count = var.scheduler == "LSF" ? (local.login_image_found_in_map ? 0 : 1) : 0
  name  = var.login_instance[count.index]["image"]
}

data "ibm_is_dedicated_host_profiles" "profiles" {
  count = var.enable_dedicated_host ? 1 : 0
}

data "ibm_is_security_group" "storage_security_group" {
  count = var.storage_security_group_name != null ? 1 : 0
  name  = var.storage_security_group_name
}

data "ibm_is_security_group" "compute_security_group" {
  count = var.compute_security_group_name != null ? 1 : 0
  name  = var.compute_security_group_name
}

data "ibm_is_security_group" "gklm_security_group" {
  count = var.gklm_security_group_name != null ? 1 : 0
  name  = var.gklm_security_group_name
}

data "ibm_is_security_group" "ldap_security_group" {
  count = var.ldap_security_group_name != null ? 1 : 0
  name  = var.ldap_security_group_name
}

data "ibm_is_security_group" "client_security_group" {
  count = var.client_security_group_name != null ? 1 : 0
  name  = var.client_security_group_name
}
