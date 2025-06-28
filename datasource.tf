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

#Fetching Existing VPC CIDR for Security rules:
data "ibm_is_vpc" "existing_vpc" {
  count = var.vpc_name != null ? 1 : 0
  name  = var.vpc_name
}

data "ibm_is_vpc_address_prefixes" "existing_vpc_cidr" {
  count = var.vpc_name != null ? 1 : 0
  vpc   = data.ibm_is_vpc.existing_vpc[0].id
}

/*
data "ibm_is_subnet" "subnet" {
  count      = length(local.subnets)
  identifier = local.subnets[count.index]["id"]
}
*/

# data "ibm_resource_group" "existing_resource_group" {
#   count = var.existing_resource_group == null ? 0 : 1
#   name  = var.existing_resource_group
# }

data "ibm_is_subnet" "existing_cluster_subnets" {
  count      = var.vpc_name != null && var.cluster_subnet_id != null ? 1 : 0
  identifier = var.cluster_subnet_id
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

data "ibm_is_subnet" "existing_login_subnets" {
  count      = var.vpc_name != null && var.login_subnet_id != null ? 1 : 0
  identifier = var.login_subnet_id
}

data "ibm_is_ssh_key" "ssh_keys" {
  for_each = toset(var.ssh_keys)
  name     = each.key
}

data "ibm_is_subnet" "compute_subnet_crn" {
  count      = var.vpc_name != null && var.cluster_subnet_id != null ? 1 : 0
  identifier = local.compute_subnet_id
}

data "ibm_is_instance_profile" "compute_profile" {
  name = local.compute_vsi_profile[0]
}

data "ibm_is_instance_profile" "storage_profile" {
  name = local.storage_vsi_profile[0]
}

data "ibm_is_bare_metal_server_profile" "storage_bms_profile" {
  count = var.scheduler == "Scale" ? 1 : 0
  name  = local.storage_bms_profile[0]
}

data "ibm_is_instance_profile" "management_profile" {
  name = local.management_vsi_profile[0]
}

data "ibm_is_instance_profile" "protocol_profile" {
  count = local.ces_server_type == false && (local.scale_ces_enabled == true && var.colocate_protocol_instances == false) ? 1 : 0
  name  = local.protocol_vsi_profile[0]
}

data "ibm_is_subnet_reserved_ips" "protocol_subnet_reserved_ips" {
  count  = local.scale_ces_enabled == true ? 1 : 0
  subnet = local.protocol_subnet_id
}

data "ibm_is_instance_profile" "afm_server_profile" {
  count = local.afm_server_type == false ? 1 : 0
  name  = local.afm_vsi_profile[0]
}
