data "ibm_is_region" "region" {
  name = local.region
}

data "ibm_is_vpc" "itself" {
  count = var.vpc_name == null ? 0 : 1
  name  = var.vpc_name
}

locals {
  vpc_name = var.vpc_name == null ? one(module.landing_zone[0].vpc_name) : var.vpc_name
  # region_name = [for zone in var.zones : join("-", slice(split("-", zone), 0, 2))][0]
  api_endpoint_region_map = {
    "us-east"  = "https://api.us-east.codeengine.cloud.ibm.com/v2beta"
    "eu-de"    = "https://api.eu-de.codeengine.cloud.ibm.com/v2beta"
    "us-south" = "https://api.us-south.codeengine.cloud.ibm.com/v2beta"
  }
  ldap_server_status = var.enable_ldap == true && var.ldap_server == "null" ? false : true

  # Decode the JSON reply got from the Code Engine API
  # https://hpc-api.<REGION>.codeengine.cloud.ibm.com/v3/capacity_reservations
  # Verify if in the capacity_reservations list there is one with the name equal to the Contract ID.
  reservation_id_found = try(length([for res in local.reservation_data.capacity_reservations : res if res.name == var.reservation_id]), 0) > 0
  # Verify if the status code is 200
  reservation_data  = var.solution == "hpc" ? jsondecode(data.http.reservation_id_validation[0].response_body) : null
  valid_status_code = var.solution == "hpc" ? contains(["200"], tostring(data.http.reservation_id_validation[0].status_code)) : false

}

data "ibm_is_vpc" "existing_vpc" {
  # Lookup for this VPC resource only if var.vpc_name is not empty
  count = var.vpc_name != null ? 1 : 0
  name  = var.vpc_name
}

data "ibm_is_vpc" "vpc" {
  name = local.vpc_name
  # Depends on creation of new VPC or look up of existing VPC based on value of var.vpc_name,
  depends_on = [module.landing_zone.vpc_name, data.ibm_is_vpc.existing_vpc]
}

data "ibm_is_subnet" "existing_subnet" {
  # Lookup for this Subnet resources only if var.cluster_subnet_ids is not empty
  count      = (length(var.cluster_subnet_ids) == 1 && var.vpc_name != null) ? length(var.cluster_subnet_ids) : 0
  identifier = var.cluster_subnet_ids[count.index]
}

data "ibm_is_subnet" "existing_login_subnet" {
  # Lookup for this Subnet resources only if var.login_subnet_id is not empty
  count      = (var.login_subnet_id != null && var.vpc_name != null) ? 1 : 0
  identifier = var.login_subnet_id
}

# Validating Contract ID
data "ibm_iam_auth_token" "auth_token" {}

data "http" "reservation_id_validation" {
  count  = var.solution == "hpc" ? 1 : 0
  url    = "${local.api_endpoint_region_map[local.region]}/capacity_reservations"
  method = "GET"
  request_headers = {
    Accept        = "application/json"
    Authorization = data.ibm_iam_auth_token.auth_token.iam_access_token
    # Content-Type  = "application/json"
  }
}

# Code for Public Gateway attachment for the existing vpc and new subnets scenario

data "ibm_is_public_gateways" "public_gateways" {
}

locals {
  public_gateways_list = data.ibm_is_public_gateways.public_gateways.public_gateways
  zone_1_pgw_ids       = var.vpc_name != null ? [for gateway in local.public_gateways_list : gateway.id if gateway.vpc == local.vpc_id && gateway.zone == var.zones[0]] : []
}

resource "ibm_is_subnet_public_gateway_attachment" "zone_1_attachment" {
  count          = (var.vpc_name != null && length(var.cluster_subnet_ids) == 0) ? 1 : 0
  subnet         = local.compute_subnets[0].id
  public_gateway = length(local.zone_1_pgw_ids) > 0 ? local.zone_1_pgw_ids[0] : ""
}
