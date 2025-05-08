# define variables
locals {
  prefix            = var.prefix
  storage_image_id  = data.ibm_is_image.storage[*].id
  storage_node_name = format("%s-%s", local.prefix, "strg")
  resource_group_id = data.ibm_resource_group.existing_resource_group.id
  bms_interfaces    = ["eth0", "eth1"]
  # bms_interfaces    = ["ens1", "ens2"]
  # storage_ssh_keys  = [for name in var.storage_ssh_keys : data.ibm_is_ssh_key.storage[name].id]

  # TODO: explore (DA always keep it true)
  #skip_iam_authorization_policy = true
  storage_server_count = sum(var.storage_servers[*]["count"])
  enable_storage       = local.storage_server_count > 0
}
