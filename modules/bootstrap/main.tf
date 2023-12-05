module "bootstrap_vsi" {
  count                         = var.enable_bootstrap ? 1 : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "3.0.0"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = local.bootstrap_image_id
  machine_type                  = var.bootstrap_instance_profile
  prefix                        = local.bootstrap_node_name
  resource_group_id             = var.resource_group_id
  enable_floating_ip            = false
  security_group_ids            = var.security_group_ids
  ssh_key_ids                   = var.ssh_keys
  subnets                       = local.bastion_subnets
  tags                          = local.tags
  user_data                     = data.template_file.bootstrap_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = var.enable_bastion ? true : false
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  existing_kms_instance_guid    = var.existing_kms_instance_guid
}
