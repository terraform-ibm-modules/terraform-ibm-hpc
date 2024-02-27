module "ssh_key" {
  count            = 1
  source           = "./../key"
  private_key_path = "bastion_id_rsa" #checkov:skip=CKV_SECRET_6
}

module "bastion_sg" {
  count                        = 1
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.6.0"
  add_ibm_cloud_internal_rules = true
  resource_group               = var.resource_group
  security_group_name          = format("%s-bastion-sg", local.prefix)
  security_group_rules         = local.bastion_security_group_rules
  vpc_id                       = var.vpc_id
  tags                         = local.tags  
}

module "bastion_vsi" {
  count                         = 1
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "3.2.1"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = local.bastion_image_id
  machine_type                  = local.bastion_machine_type
  prefix                        = local.bastion_node_name
  resource_group_id             = var.resource_group
  enable_floating_ip            = true
  security_group_ids            = module.bastion_sg[*].security_group_id
  ssh_key_ids                   = local.bastion_ssh_keys
  subnets                       = length(var.bastion_subnets) == 3 ? [local.bastion_subnets[2]] : [local.bastion_subnets[0]]
  tags                          = local.tags
  user_data                     = data.template_file.bastion_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = var.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  existing_kms_instance_guid    = var.existing_kms_instance_guid
}

# module "bootstrap_vsi" {
#   count                         = local.enable_bootstrap ? 1 : 0
#   source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
#   version                       = "3.2.1"
#   vsi_per_subnet                = 1
#   create_security_group         = false
#   security_group                = null
#   image_id                      = local.bootstrap_image_id
#   machine_type                  = var.bootstrap_instance_profile
#   prefix                        = local.bootstrap_node_name
#   resource_group_id             = local.resource_group_id
#   enable_floating_ip            = false
#   security_group_ids            = module.bastion_sg[*].security_group_id
#   ssh_key_ids                   = local.bastion_ssh_keys
#   subnets                       = local.bastion_subnets
#   tags                          = local.tags
#   user_data                     = data.template_file.bootstrap_user_data.rendered
#   vpc_id                        = var.vpc_id
#   kms_encryption_enabled        = var.kms_encryption_enabled
#   skip_iam_authorization_policy = var.enable_bastion ? true : false
#   boot_volume_encryption_key    = var.boot_volume_encryption_key
#   existing_kms_instance_guid    = var.existing_kms_instance_guid
# }
