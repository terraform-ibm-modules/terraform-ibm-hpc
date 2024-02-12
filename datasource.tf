locals {
    vpc_name = var.vpc_name == null ? one(module.hpc.vpc_name) : var.vpc_name
    region_name = [for zone in var.zones : join("-", slice(split("-", zone), 0, 2))][0]
    api_endpoint_region_map = {
        "us-east" = "https://hpc-api.us-east.codeengine.cloud.ibm.com/v2"
        "eu-de"   = "https://hpc-api.eu-de.codeengine.cloud.ibm.com/v2"
    }
    ldap_server_status = var.enable_ldap == true && var.ldap_server == "null" ? false : true
}

data "ibm_is_region" "region" {
  name = local.region_name
}

data "ibm_is_vpc" "existing_vpc" {
  // Lookup for this VPC resource only if var.vpc_name is not empty
  count = var.vpc_name != null ? 1 : 0
  name  = var.vpc_name
}

data "ibm_is_vpc" "vpc" {
  name = local.vpc_name
  // Depends on creation of new VPC or look up of existing VPC based on value of var.vpc_name,
  depends_on = [module.hpc.vpc_name, data.ibm_is_vpc.existing_vpc]
}

data "ibm_is_vpc_address_prefixes" "existing_vpc" {
  #count = var.vpc_name != "" ? 1 : 0
  vpc = data.ibm_is_vpc.vpc.id
}

data "ibm_is_subnet" "existing_subnet" {
  // Lookup for this Subnet resources only if var.subnet_id is not empty
  count      = length(var.subnet_id) > 1 ? length(var.subnet_id) : 0
  identifier = var.subnet_id[count.index]
}

# Validating Contract ID
data "ibm_iam_auth_token" "auth_token" {}

data "http" "contract_id_validation" {
  url    = "${lookup(local.api_endpoint_region_map, local.region_name)}/capacity_requests/check"
  method = "POST"
  request_headers = {
    accept        = "application/json"
    Authorization = data.ibm_iam_auth_token.auth_token.iam_access_token
    Content-Type  = "application/json"
  }
  request_body = jsonencode({
    "cluster" = {
      "id" = "${var.contract_id}_${var.cluster_id}"
    }
    "contract" = {
      "id" = var.contract_id
    }
  })
}
