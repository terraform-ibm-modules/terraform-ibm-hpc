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

data "ibm_is_subnet" "existing_storage_subnets" {
  count = var.vpc != null && var.storage_subnets != null ? 1 : 0
  name  = var.storage_subnets[count.index]
}

data "ibm_is_subnet" "existing_protocol_subnets" {
  count = var.vpc != null && var.protocol_subnets != null ? 1 : 0
  name  = var.protocol_subnets[count.index]
}

data "ibm_is_subnet" "existing_client_subnets" {
  count = var.vpc != null && var.client_subnets != null ? 1 : 0
  name  = var.client_subnets[count.index]
}

data "ibm_is_subnet" "existing_bastion_subnets" {
  count = var.vpc != null && var.bastion_subnets != null ? 1 : 0
  name  = var.bastion_subnets[count.index]
}

# New Code
data "ibm_is_instance_profile" "dynmaic_worker_profile" {
  name = var.dynamic_compute_instances[0].profile
}

data "ibm_is_image" "dynamic_compute" {
  name = var.dynamic_compute_instances[0].image
}

data "ibm_is_ssh_key" "compute_ssh_keys" {
  for_each = toset(local.compute_ssh_keys)
  name     = each.key
}

data "ibm_is_subnet" "compute_subnet_crn" {
  identifier = local.compute_subnet_id
}