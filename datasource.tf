# Future use
/*
data "ibm_is_region" "region" {
  name = local.region
}

data "ibm_is_zone" "zone" {
  name   = var.zones[0]
  region = data.ibm_is_region.region.name
}
*/


data "ibm_is_vpc" "existing_vpc" {
  count = var.vpc_name != null ? 1 : 0
  name  = var.vpc_name
}

/*
data "ibm_is_subnet" "subnet" {
  count      = length(local.subnets)
  identifier = local.subnets[count.index]["id"]
}
*/

data "ibm_resource_group" "resource_group" {
  count = var.existing_resource_group == null ? 0 : 1
  name  = var.existing_resource_group
}

data "ibm_is_subnet" "existing_compute_subnets" {
  count = var.vpc_name != null && var.compute_subnets != null ? 1 : 0
  name  = var.compute_subnets[count.index]
}

data "ibm_is_subnet" "existing_storage_subnets" {
  count = var.vpc_name != null && var.storage_subnets != null ? 1 : 0
  name  = var.storage_subnets[count.index]
}

data "ibm_is_subnet" "existing_protocol_subnets" {
  count = var.vpc_name != null && var.protocol_subnets != null ? 1 : 0
  name  = var.protocol_subnets[count.index]
}

data "ibm_is_subnet" "existing_client_subnets" {
  count = var.vpc_name != null && var.client_subnets != null ? 1 : 0
  name  = var.client_subnets[count.index]
}

data "ibm_is_subnet" "existing_bastion_subnets" {
  count = var.vpc_name != null && var.bastion_subnets != null ? 1 : 0
  name  = var.bastion_subnets[count.index]
}
