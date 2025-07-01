resource "ibm_is_subnet_public_gateway_attachment" "zone_1_attachment" {
  count          = (var.ext_vpc_name != null && var.ext_cluster_subnet_id == null) ? 1 : 0
  subnet         = var.cluster_subnets[0].id
  public_gateway = length(local.zone_1_pgw_ids) > 0 ? local.zone_1_pgw_ids[0] : ""
}

resource "ibm_is_subnet_public_gateway_attachment" "bastion_attachment" {
  count          = (var.ext_vpc_name != null && var.ext_login_subnet_id == null) ? 1 : 0
  subnet         = local.bastion_subnets[0].id
  public_gateway = length(local.zone_1_pgw_ids) > 0 ? local.zone_1_pgw_ids[0] : ""
}

module "ssh_key" {
  count            = var.enable_deployer ? 1 : 0
  source           = "./../key"
  private_key_path = "bastion_id_rsa" #checkov:skip=CKV_SECRET_6
}

module "bastion_sg" {
  count                        = var.enable_deployer ? 1 : 0
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.6.2"
  add_ibm_cloud_internal_rules = true
  resource_group               = var.resource_group
  security_group_name          = format("%s-bastion-sg", local.prefix)
  security_group_rules         = local.bastion_security_group_rules
  vpc_id                       = var.vpc_id
}

module "bastion_vsi" {
  count                         = (var.enable_deployer && var.bastion_instance_name == null) ? 1 : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "5.0.0"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = local.bastion_image_id
  machine_type                  = var.bastion_instance["profile"]
  prefix                        = local.bastion_node_name
  resource_group_id             = var.resource_group
  enable_floating_ip            = true
  security_group_ids            = module.bastion_sg[*].security_group_id
  ssh_key_ids                   = local.bastion_ssh_keys
  subnets                       = local.bastion_subnets
  tags                          = local.tags
  user_data                     = data.template_file.bastion_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = true
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  existing_kms_instance_guid    = var.existing_kms_instance_guid
}

module "deployer_vsi" {
  count                         = local.enable_deployer ? 1 : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "5.0.0"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = local.deployer_image_found_in_map ? local.new_deployer_image_id : data.ibm_is_image.deployer[0].id
  machine_type                  = var.deployer_instance["profile"]
  prefix                        = local.deployer_node_name
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = module.bastion_sg[*].security_group_id
  ssh_key_ids                   = local.bastion_ssh_keys
  subnets                       = local.bastion_subnets
  tags                          = local.tags
  user_data                     = data.template_file.deployer_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = var.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  existing_kms_instance_guid    = var.existing_kms_instance_guid
}
