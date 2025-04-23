data "ibm_resource_group" "existing_resource_group" {
  name = var.existing_resource_group
}

data "ibm_is_image" "storage" {
  count = length(var.storage_servers)
  name  = var.storage_servers[count.index]["image"]
}

/*data "ibm_is_ssh_key" "storage" {
  for_each = toset(var.storage_ssh_keys)
  name     = each.key
}*/

data "ibm_is_instance_profile" "storage" {
  count = length(var.storage_servers)
  name  = var.storage_servers[count.index]["profile"]
}

data "ibm_is_instance_profile" "storage_tie_instance" {
  count = length(var.storage_servers)
  name  = var.storage_servers[count.index]["profile"]
}