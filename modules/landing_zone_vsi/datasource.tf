# data "ibm_resource_group" "itself" {
#   name = var.resource_group
# }

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


# data "ibm_is_image" "login" {
#   name = var.login_image_name
# }

data "ibm_is_image" "management" {
  name  = var.management_image_name
  count = local.image_mapping_entry_found ? 0 : 1
}

data "ibm_is_image" "compute" {
  name  = var.compute_image_name
  count = local.compute_image_mapping_entry_found ? 0 : 1
}

# data "ibm_is_image" "storage" {
#   name = var.storage_image_name
# }


# data "ibm_is_ssh_key" "login" {
#   for_each = toset(var.login_ssh_keys)
#   name     = each.key
# }

#data "ibm_is_subnet" "compute" {
#for_each = { for subnet in local.compute_subnets : subnet.name => subnet }
#name    = each.key
#}

data "ibm_is_ssh_key" "compute" {
  for_each = toset(var.compute_ssh_keys)
  name     = each.key
}

# data "ibm_is_ssh_key" "storage" {
#   for_each = toset(var.storage_ssh_keys)
#   name     = each.key
# }

data "ibm_is_region" "region" {
  name = local.region
}

data "ibm_is_instance_profile" "management_node" {
  name = var.management_node_instance_type
}

data "ibm_is_ssh_key" "bastion" {
  for_each = toset(var.ssh_keys)
  name     = each.key
}

data "ibm_is_image" "ldap_vsi_image" {
  name  = var.ldap_vsi_osimage_name
  count = var.ldap_basedns != null && var.ldap_server == "null" ? 1 : 0
}
