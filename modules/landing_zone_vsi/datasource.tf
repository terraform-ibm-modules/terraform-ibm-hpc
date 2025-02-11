data "ibm_is_image" "management" {
  name  = var.management_image_name
  count = local.image_mapping_entry_found ? 0 : 1
}

data "ibm_is_image" "compute" {
  name  = var.compute_image_name
  count = local.compute_image_from_data ? 1 : 0
}

data "ibm_is_image" "login" {
  name  = var.login_image_name
  count = local.login_image_mapping_entry_found ? 0 : 1
}

data "ibm_is_ssh_key" "compute" {
  for_each = toset(var.compute_ssh_keys)
  name     = each.key
}

data "ibm_is_region" "region" {
  name = local.region
}

data "ibm_is_instance_profile" "management_node" {
  name = var.management_node_instance_type
}

data "ibm_is_instance_profile" "worker_node" {
  name = var.worker_node_instance_type[0].instance_type
}

data "ibm_is_ssh_key" "bastion" {
  for_each = toset(var.ssh_keys)
  name     = each.key
}

data "ibm_is_image" "ldap_vsi_image" {
  name  = var.ldap_vsi_osimage_name
  count = var.ldap_basedns != null && var.ldap_server == "null" ? 1 : 0
}
