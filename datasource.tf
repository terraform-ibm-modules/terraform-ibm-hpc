# Future use
/*
data "ibm_is_region" "itself" {
  name = local.region
}

data "ibm_is_zone" "itself" {
  name   = var.zones[0]
  region = data.ibm_is_region.itself.name
}
*/

data "ibm_is_vpc" "itself" {
  count = var.vpc == null ? 0 : 1
  name  = var.vpc
}
/*
data "ibm_is_subnet" "itself" {
  count      = length(local.subnets)
  identifier = local.subnets[count.index]["id"]
}
*/

data "ibm_resource_group" "resource_group" {
  count = var.resource_group == null ? 0 : 1
  name  = var.resource_group
}

data "ibm_is_subnet" "existing_compute_subnets" {
  count = var.vpc != null && var.compute_subnets != null ? 1 : 0
  name  = var.compute_subnets[count.index]
}
