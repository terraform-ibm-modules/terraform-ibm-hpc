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
  count = var.vpc == "null" ? 0 : 1
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
