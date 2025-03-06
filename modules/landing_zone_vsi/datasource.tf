data "ibm_resource_group" "itself" {
  name = var.resource_group
}

# TODO: Verify distinct profiles
/*
data "ibm_is_instance_profile" "management" {
  name = var.management_profile
}

data "ibm_is_instance_profile" "compute" {
  name = var.compute_profile
}

data "ibm_is_instance_profile" "storage" {
  name = var.storage_profile
}

data "ibm_is_instance_profile" "protocol" {
  name = var.protocol_profile
}
*/

data "ibm_is_image" "client" {
  count = length(var.client_instances)
  name  = var.client_instances[count.index]["image"]
}

data "ibm_is_image" "management" {
  count = length(var.management_instances)
  name  = var.management_instances[count.index]["image"]
}

data "ibm_is_image" "compute" {
  count = length(var.static_compute_instances)
  name  = var.static_compute_instances[count.index]["image"]
}

data "ibm_is_image" "storage" {
  count = length(var.storage_instances)
  name  = var.storage_instances[count.index]["image"]
}

data "ibm_is_image" "protocol" {
  count = length(var.protocol_instances)
  name  = var.protocol_instances[count.index]["image"]
}


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
