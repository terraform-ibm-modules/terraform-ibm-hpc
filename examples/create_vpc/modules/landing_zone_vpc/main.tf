module "create_vpc" {
  source               = "terraform-ibm-modules/landing-zone-vpc/ibm"
  version              = "7.25.2"
  prefix               = local.prefix
  region               = local.region
  tags                 = local.tags
  resource_group_id    = local.resource_group_id
  name                 = local.name
  use_public_gateways  = local.use_public_gateways
  subnets              = local.subnets
  address_prefixes     = local.address_prefixes
  security_group_rules = local.bastion_security_group_rules
  network_acls         = local.network_acls
  enable_hub           = var.enable_hub
}
