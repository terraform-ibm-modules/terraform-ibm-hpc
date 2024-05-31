module "compute_key" {
  count            = local.enable_compute ? 1 : 0
  source           = "./../key"
  private_key_path = "compute_id_rsa" #checkov:skip=CKV_SECRET_6
}

module "storage_key" {
  count            = local.enable_storage ? 1 : 0
  source           = "./../key"
  private_key_path = "storage_id_rsa" #checkov:skip=CKV_SECRET_6
}

module "login_sg" {
  count                        = local.enable_login ? 1 : 0
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.6.1"
  add_ibm_cloud_internal_rules = true
  resource_group               = local.resource_group_id
  security_group_name          = format("%s-login-sg", local.prefix)
  security_group_rules         = local.login_security_group_rules
  vpc_id                       = var.vpc_id
}

module "compute_sg" {
  count                        = local.enable_compute ? 1 : 0
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.6.1"
  add_ibm_cloud_internal_rules = true
  resource_group               = local.resource_group_id
  security_group_name          = format("%s-comp-sg", local.prefix)
  security_group_rules         = local.compute_security_group_rules
  vpc_id                       = var.vpc_id
}

module "storage_sg" {
  count                        = local.enable_storage ? 1 : 0
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.6.1"
  add_ibm_cloud_internal_rules = true
  resource_group               = local.resource_group_id
  security_group_name          = format("%s-strg-sg", local.prefix)
  security_group_rules         = local.storage_security_group_rules
  vpc_id                       = var.vpc_id
}


module "login_vsi" {
  count                         = length(var.login_instances)
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.0.0"
  vsi_per_subnet                = var.login_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  image_id                      = local.login_image_id
  machine_type                  = var.login_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.login_node_name : format("%s-%s", local.login_node_name, count.index)
  resource_group_id             = local.resource_group_id
  enable_floating_ip            = false
  security_group_ids            = module.login_sg[*].security_group_id
  ssh_key_ids                   = local.login_ssh_keys
  subnets                       = local.login_subnets
  tags                          = local.tags
  user_data                     = data.template_file.login_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
}

module "management_vsi" {
  count                         = length(var.management_instances)
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.0.0"
  vsi_per_subnet                = var.management_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  image_id                      = local.management_image_id
  machine_type                  = var.management_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.management_node_name : format("%s-%s", local.management_node_name, count.index)
  resource_group_id             = local.resource_group_id
  enable_floating_ip            = false
  security_group_ids            = module.compute_sg[*].security_group_id
  ssh_key_ids                   = local.management_ssh_keys
  subnets                       = local.compute_subnets
  tags                          = local.tags
  user_data                     = data.template_file.management_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  placement_group_id            = var.placement_group_ids
  #placement_group_id = var.placement_group_ids[(var.management_instances[count.index]["count"])%(length(var.placement_group_ids))]
}

module "compute_vsi" {
  count                         = length(var.static_compute_instances)
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.0.0"
  vsi_per_subnet                = var.static_compute_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  image_id                      = local.compute_image_id
  machine_type                  = var.static_compute_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.compute_node_name : format("%s-%s", local.compute_node_name, count.index)
  resource_group_id             = local.resource_group_id
  enable_floating_ip            = false
  security_group_ids            = module.compute_sg[*].security_group_id
  ssh_key_ids                   = local.compute_ssh_keys
  subnets                       = local.compute_subnets
  tags                          = local.tags
  user_data                     = data.template_file.compute_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  placement_group_id            = var.placement_group_ids
  #placement_group_id = var.placement_group_ids[(var.static_compute_instances[count.index]["count"])%(length(var.placement_group_ids))]
}

module "storage_vsi" {
  count                         = length(var.storage_instances)
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.0.0"
  vsi_per_subnet                = var.storage_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  image_id                      = local.storage_image_id
  machine_type                  = var.storage_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.storage_node_name : format("%s-%s", local.storage_node_name, count.index)
  resource_group_id             = local.resource_group_id
  enable_floating_ip            = false
  security_group_ids            = module.storage_sg[*].security_group_id
  ssh_key_ids                   = local.storage_ssh_keys
  subnets                       = local.storage_subnets
  tags                          = local.tags
  user_data                     = data.template_file.storage_user_data.rendered
  vpc_id                        = var.vpc_id
  block_storage_volumes         = local.enable_block_storage ? local.block_storage_volumes : []
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  placement_group_id            = var.placement_group_ids
  #placement_group_id = var.placement_group_ids[(var.storage_instances[count.index]["count"])%(length(var.placement_group_ids))]
}

module "protocol_vsi" {
  count                         = length(var.protocol_instances)
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "4.0.0"
  vsi_per_subnet                = var.protocol_instances[count.index]["count"]
  create_security_group         = false
  security_group                = null
  image_id                      = local.protocol_image_id
  machine_type                  = var.protocol_instances[count.index]["profile"]
  prefix                        = count.index == 0 ? local.protocol_node_name : format("%s-%s", local.protocol_node_name, count.index)
  resource_group_id             = local.resource_group_id
  enable_floating_ip            = false
  security_group_ids            = module.storage_sg[*].security_group_id
  ssh_key_ids                   = local.protocol_ssh_keys
  subnets                       = local.storage_subnets
  tags                          = local.tags
  user_data                     = data.template_file.protocol_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = local.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  # Bug: 5847 - LB profile & subnets are not configurable
  # load_balancers        = local.enable_load_balancer ? local.load_balancers : []
  secondary_allow_ip_spoofing = true
  secondary_security_groups   = local.protocol_secondary_security_group
  secondary_subnets           = local.protocol_subnets
  placement_group_id          = var.placement_group_ids
  #placement_group_id = var.placement_group_ids[(var.protocol_instances[count.index]["count"])%(length(var.placement_group_ids))]
}
