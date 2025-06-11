data "ibm_is_subnet" "existing_login_subnets" {
  count      = var.vpc_name != null && var.login_subnet_id != null ? 1 : 0
  identifier = var.login_subnet_id
}

data "ibm_is_vpc" "existing_vpc" {
  count = var.vpc_name != null ? 1 : 0
  name  = var.vpc_name
}

data "ibm_is_subnet" "existing_cluster_subnets" {
  count      = var.vpc_name != null && var.cluster_subnet_ids != null ? 1 : 0
  identifier = var.cluster_subnet_ids
}
