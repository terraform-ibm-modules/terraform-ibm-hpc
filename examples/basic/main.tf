module "hpc-basic-example" {
  source               = "../.."
  ibmcloud_api_key     = var.ibmcloud_api_key
  resource_group       = var.resource_group
  prefix               = var.prefix
  zones                = var.zones
  allowed_cidr         = var.allowed_cidr
  bastion_ssh_keys     = var.bastion_ssh_keys
  login_ssh_keys       = var.login_ssh_keys
  compute_ssh_keys     = var.compute_ssh_keys
  storage_ssh_keys     = var.storage_ssh_keys
  compute_gui_password = var.compute_gui_password
  storage_gui_password = var.storage_gui_password
}