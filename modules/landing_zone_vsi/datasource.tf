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

data "ibm_is_image" "login" {
  name = var.login_image_name
}

data "ibm_is_image" "management" {
  name = var.management_image_name
}

data "ibm_is_image" "compute" {
  name = var.compute_image_name
}

data "ibm_is_image" "storage" {
  name = var.storage_image_name
}


data "ibm_is_ssh_key" "login" {
  for_each = toset(var.login_ssh_keys)
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
