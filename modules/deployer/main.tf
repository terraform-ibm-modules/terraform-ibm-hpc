resource "ibm_is_subnet_public_gateway_attachment" "zone_1_attachment" {
  count          = (var.ext_vpc_name != null && var.ext_compute_subnet_id == null && length(var.compute_subnets) > 0 && length(local.zone_1_pgw_ids) > 0) ? 1 : 0
  subnet         = var.compute_subnets[0].id
  public_gateway = local.zone_1_pgw_ids[0]
}

resource "ibm_is_subnet_public_gateway_attachment" "bastion_attachment" {
  count          = (var.ext_vpc_name != null && var.ext_login_subnet_id == null && length(var.bastion_subnets) > 0 && length(local.zone_1_pgw_ids) > 0) ? 1 : 0
  subnet         = local.bastion_subnets[0].id
  public_gateway = local.zone_1_pgw_ids[0]
}

resource "ibm_is_subnet_public_gateway_attachment" "storage_attachment" {
  count          = (var.ext_vpc_name != null && var.ext_storage_subnet_id == null && length(var.storage_subnets) > 0 && length(local.zone_1_pgw_ids) > 0) ? 1 : 0
  subnet         = var.storage_subnets[0].id
  public_gateway = local.zone_1_pgw_ids[0]
}

resource "ibm_is_subnet_public_gateway_attachment" "client_attachment" {
  count          = (var.ext_vpc_name != null && var.ext_client_subnet_id == null && length(var.client_subnets) > 0 && length(local.zone_1_pgw_ids) > 0) ? 1 : 0
  subnet         = var.client_subnets[0].id
  public_gateway = local.zone_1_pgw_ids[0]
}

resource "ibm_is_subnet_public_gateway_attachment" "protocol_attachment" {
  count          = (var.ext_vpc_name != null && var.ext_protocol_subnet_id == null && length(var.protocol_subnets) > 0 && length(local.zone_1_pgw_ids) > 0) ? 1 : 0
  subnet         = var.protocol_subnets[0].id
  public_gateway = local.zone_1_pgw_ids[0]
}

module "ssh_key" {
  count            = var.enable_deployer ? 1 : 0
  source           = "./../key"
  private_key_path = "bastion_id_rsa" #checkov:skip=CKV_SECRET_6
}

module "bastion_sg" {
  count                        = var.enable_deployer && var.login_security_group_name == null ? 1 : 0
  source                       = "terraform-ibm-modules/security-group/ibm"
  version                      = "2.6.2"
  add_ibm_cloud_internal_rules = true
  resource_group               = var.resource_group
  security_group_name          = format("%s-bastion-sg", local.prefix)
  security_group_rules         = local.bastion_security_group_rules
  vpc_id                       = var.vpc_id
}

module "bastion_vsi" {
  count  = (var.enable_deployer && var.bastion_instance_name == null) ? 1 : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "5.4.16"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = local.bastion_image_id
  machine_type                  = var.bastion_instance["profile"]
  prefix                        = local.bastion_node_name
  resource_group_id             = var.resource_group
  enable_floating_ip            = true
  security_group_ids            = var.login_security_group_name == null ? module.bastion_sg[*].security_group_id : local.login_security_group_name_id
  ssh_key_ids                   = local.bastion_ssh_keys
  subnets                       = var.scheduler == "Scale" && var.enable_sec_interface_compute ? var.storage_subnets : local.bastion_subnets
  tags                          = local.tags
  user_data                     = data.template_file.bastion_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = true
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  secondary_security_groups     = var.scheduler == "Scale" && var.enable_sec_interface_compute ? local.storage_secondary_security_group : []
  secondary_subnets             = var.scheduler == "Scale" && var.enable_sec_interface_compute ? var.compute_subnets : []
  manage_reserved_ips           = var.scheduler == "Scale" && var.enable_sec_interface_compute ? true : false
}

module "deployer_vsi" {
  count                         = local.enable_deployer ? 1 : 0
  source                        = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                       = "5.4.6"
  vsi_per_subnet                = 1
  create_security_group         = false
  security_group                = null
  image_id                      = local.deployer_image_found_in_map ? local.new_deployer_image_id : data.ibm_is_image.deployer[0].id
  machine_type                  = var.deployer_instance["profile"]
  prefix                        = local.deployer_node_name
  resource_group_id             = var.resource_group
  enable_floating_ip            = false
  security_group_ids            = var.login_security_group_name == null ? module.bastion_sg[*].security_group_id : local.login_security_group_name_id
  ssh_key_ids                   = local.bastion_ssh_keys
  subnets                       = var.scheduler == "Scale" && var.enable_sec_interface_compute ? var.storage_subnets : local.bastion_subnets
  tags                          = local.tags
  user_data                     = data.template_file.deployer_user_data.rendered
  vpc_id                        = var.vpc_id
  kms_encryption_enabled        = var.kms_encryption_enabled
  skip_iam_authorization_policy = var.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
}
