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
