data "ibm_is_region" "region" {
  name = local.region
}

data "ibm_is_vpc" "itself" {
  count = var.vpc == "null" ? 0 : 1
  name  = var.vpc
}
