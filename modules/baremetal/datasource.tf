data "ibm_resource_group" "existing_resource_group" {
  name = var.existing_resource_group
}

data "ibm_is_image" "storage" {
  count = length(var.storage_servers)
  name  = var.storage_servers[count.index]["image"]
}
