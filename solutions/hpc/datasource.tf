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

# data "ibm_is_vpc" "vpc" {
#   name = local.vpc_name
#   // Depends on creation of new VPC or look up of existing VPC based on value of var.vpc_name,
#   depends_on = [module.landing_zone, data.ibm_is_vpc.itself]
# }

# data "ibm_is_vpc_address_prefixes" "existing_vpc" {
#   #count = var.vpc_name != "" ? 1 : 0
#   vpc = data.ibm_is_vpc.vpc.id
# }

data "ibm_is_region" "region" {
  name = local.region
}

# data "ibm_is_floating_ips" "fip" {
#   count = var.enable_fip ? 0 : 1
#   name = local.bastion_fip_name
# }

/*
data "ibm_is_subnet" "itself" {
  count      = length(local.subnets)
  identifier = local.subnets[count.index]["id"]
}
*/


data "ibm_is_vpc" "existing_vpc" {
  // Lookup for this VPC resource only if var.vpc_name is not empty
  count = var.vpc != null ? 1 : 0
  name  = var.vpc
}

#data "ibm_is_subnet" "subnet_id" {
#  for_each   = var.vpc == "" ? [] : toset(data.ibm_is_vpc.existing_vpc[0].subnets[*].id)
#  identifier = each.value
#}

data "ibm_is_subnet" "subnet_id" {
  for_each   = can(data.ibm_is_vpc.existing_vpc) && length(data.ibm_is_vpc.existing_vpc) > 0 ? toset(flatten([for vpc in data.ibm_is_vpc.existing_vpc : vpc.subnets[*].id])) : toset([])
  identifier = each.value
}

data "ibm_is_subnet_reserved_ips" "dns_reserved_ips" {
  for_each = toset([for subnetsdetails in data.ibm_is_subnet.subnet_id : subnetsdetails.id])
  subnet   = each.value
}

data "ibm_dns_custom_resolvers" "dns_custom_resolver" {
  count       = var.dns_instance_id != null || local.dns_service_id != "" ? 1 : 0
  instance_id = local.sagar_check
}