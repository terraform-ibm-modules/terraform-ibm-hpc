module "ldap_vsi" {
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.2.0"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = local.ldap_instance_image_id
  machine_type                  = var.ldap_vsi_profile
  prefix                        = local.ldap_node_name
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = var.compute_security_group_id
  ssh_key_ids                   = local.compute_ssh_keys
  subnets                       = [var.compute_subnets[0]]
  user_data                     = ""
  tags                          = local.tags
  vpc_id                        = var.vpc_id
}