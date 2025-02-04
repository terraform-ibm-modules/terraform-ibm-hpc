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

data "ibm_is_instance_profile" "compute_profile" {
  name = local.compute_vsi_profile[0]
}

data "ibm_is_instance_profile" "storage_profile" {
  name = local.storage_vsi_profile[0]
}

data "ibm_is_instance_profile" "management_profile" {
  name = local.management_vsi_profile[0]
}

data "ibm_is_instance_profile" "protocol_profile" {
  count = local.ces_server_type == false && (local.scale_ces_enabled == true && var.colocate_protocol_cluster_instances == false) ? 1 : 0
  name  = local.protocol_vsi_profile[0]
}

data "ibm_is_instance_profile" "afm_server_profile" {
  count = local.afm_server_type == false ? 1 : 0
  name  = local.afm_vsi_profile[0]
}
# data "ibm_is_subnet" "storage_cluster_private_subnets_cidr" {
#   identifier = var.storage_subnets_cidr[0]
# }

# data "ibm_is_subnet" "compute_cluster_private_subnets_cidr" {
#   identifier = var.client_subnets_cidr[0]
# }
