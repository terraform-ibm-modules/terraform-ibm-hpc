# module "storage_key" {
#   count  = local.enable_storage ? 1 : 0
#   source = "./../key"
# }

module "storage_baremetal" {
  source                       = "terraform-ibm-modules/bare-metal-vpc/ibm"
  version                      = "1.4.0"
  count                        = length(var.storage_servers)
  server_count                 = var.storage_servers[count.index]["count"]
  prefix                       = var.prefix
  profile                      = var.storage_servers[count.index]["profile"]
  image_id                     = var.image_id
  create_security_group        = false
  subnet_ids                   = var.storage_subnets
  ssh_key_ids                  = var.storage_ssh_keys
  bandwidth                    = var.sapphire_rapids_profile_check == true ? 200000 : 100000
  allowed_vlan_ids             = var.allowed_vlan_ids
  access_tags                  = null
  resource_group_id            = var.existing_resource_group
  security_group_ids           = var.security_group_ids
  user_data                    = var.user_data
  secondary_vni_enabled        = var.secondary_vni_enabled
  secondary_subnet_ids         = length(var.protocol_subnets) == 0 ? [] : [var.protocol_subnets[0].id]
  secondary_security_group_ids = var.secondary_security_group_ids
  tpm_mode                     = "tpm_2"
}
