module "storage_key" {
  count  = local.enable_storage ? 1 : 0
  source = "./../key"
}

module "storage_baremetal" {
  source = "git::https://github.com/Louies-Jhony/terraform-ibm-bare-metal-vpc"
  #  version      = "1.0.0"
  count                 = length(var.storage_servers)
  server_count          = var.storage_servers[count.index]["count"]
  prefix                = count.index == 0 ? local.storage_node_name : format("%s-%s", local.storage_node_name, count.index)
  profile               = var.storage_servers[count.index]["profile"]
  image_id              = local.storage_image_id[count.index]
  create_security_group = false
  subnet_ids            = var.storage_subnets
  ssh_key_ids           = var.storage_ssh_keys
  bandwidth             = var.bandwidth
  allowed_vlan_ids      = var.allowed_vlan_ids
  access_tags           = null
  resource_group_id     = local.resource_group_id
  security_group_ids    = var.security_group_ids
  user_data             = data.template_file.storage_user_data.rendered
}
