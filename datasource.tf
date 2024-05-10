locals {
  vpc_name    = var.vpc_name == "null" ? one(module.hpc.vpc_name) : var.vpc_name
  region_name = [for zone in var.zones : join("-", slice(split("-", zone), 0, 2))][0]
  api_endpoint_region_map = {
    "us-east"  = "https://hpc-api.us-east.codeengine.cloud.ibm.com/v3"
    "eu-de"    = "https://hpc-api.eu-de.codeengine.cloud.ibm.com/v3"
    "us-south" = "https://hpc-api.us-south.codeengine.cloud.ibm.com/v3"
  }
  ldap_server_status = var.enable_ldap == true && var.ldap_server == "null" ? false : true

  # Existing bastion Variables
  bastion_instance_name      = var.bastion_instance_name != "null" ? var.bastion_instance_name : null
  bastion_instance_public_ip = var.bastion_instance_name != "null" ? var.bastion_instance_public_ip : null
  bastion_security_group_id  = var.bastion_instance_name != "null" ? var.bastion_security_group_id : null
  bastion_ssh_private_key    = var.bastion_instance_name != "null" ? var.bastion_ssh_private_key : null
  bastion_instance_status    = var.bastion_instance_name != "null" ? false : true

  # NFS Mount security group
  storage_security_group_id = var.storage_security_group_id != "null" ? var.storage_security_group_id : null

  # Decode the JSON reply got from the Code Engine API
  # https://hpc-api.<REGION>.codeengine.cloud.ibm.com/v3/capacity_reservations
  reservation_data = jsondecode(data.http.contract_id_validation.response_body)
  # Verify if in the capacity_reservations list there is one with the name equal to the Contract ID.
  contract_id_found = try(length([for res in local.reservation_data.capacity_reservations : res if res.name == var.contract_id]), 0) > 0
  # Verify if the status code is 200
  valid_status_code = contains(["200"], tostring(data.http.contract_id_validation.status_code))
}

data "ibm_is_region" "region" {
  name = local.region_name
}

data "ibm_is_vpc" "existing_vpc" {
  # Lookup for this VPC resource only if var.vpc_name is not empty
  count = var.vpc_name != "null" ? 1 : 0
  name  = var.vpc_name
}

data "ibm_is_vpc" "vpc" {
  name = local.vpc_name
  # Depends on creation of new VPC or look up of existing VPC based on value of var.vpc_name,
  depends_on = [module.hpc.vpc_name, data.ibm_is_vpc.existing_vpc]
}

data "ibm_is_vpc_address_prefixes" "existing_vpc" {
  #count = var.vpc_name != "" ? 1 : 0
  vpc = data.ibm_is_vpc.vpc.id
}

data "ibm_is_subnet" "existing_subnet" {
  # Lookup for this Subnet resources only if var.cluster_subnet_ids is not empty
  count      = (length(var.cluster_subnet_ids) == 1 && var.vpc_name != "null") ? length(var.cluster_subnet_ids) : 0
  identifier = var.cluster_subnet_ids[count.index]
}

data "ibm_is_subnet" "existing_login_subnet" {
  # Lookup for this Subnet resources only if var.login_subnet_id is not empty
  count      = (var.login_subnet_id != "null" && var.vpc_name != "null") ? 1 : 0
  identifier = var.login_subnet_id
}

# Validating Contract ID
data "ibm_iam_auth_token" "auth_token" {}

data "http" "contract_id_validation" {
  url    = "${local.api_endpoint_region_map[local.region_name]}/capacity_reservations"
  method = "GET"
  request_headers = {
    Accept        = "application/json"
    Authorization = data.ibm_iam_auth_token.auth_token.iam_access_token
    #Content-Type  = "application/json"
  }
}

data "ibm_is_public_gateways" "public_gateways" {
}

locals {
  public_gateways_list = data.ibm_is_public_gateways.public_gateways.public_gateways
  zone_1_pgw_id        = var.vpc_name != "null" ? [for gateway in local.public_gateways_list : gateway.id if gateway.vpc == data.ibm_is_vpc.existing_vpc[0].id && gateway.zone == var.zones[0]] : []
}
