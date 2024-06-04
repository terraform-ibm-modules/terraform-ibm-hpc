##############################################################################
# VPC GUID
##############################################################################

output "vpc_name" {
  description = "VPC name"
  value       = module.create_vpc.vpc_name[0]
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.create_vpc.vpc_id[0]
}

output "vpc_crn" {
  description = "VPC CRN"
  value       = module.create_vpc.vpc_crn[0]
}

output "cidr_blocks" {
  description = "List of CIDR blocks present in VPC stack"
  value       = module.create_vpc.cidr_blocks[0]
}

##############################################################################
# Hub and Spoke specific configuration
##############################################################################

output "custom_resolver_hub" {
  description = "The custom resolver created for the hub vpc. Only set if enable_hub is set and skip_custom_resolver_hub_creation is false."
  value       = module.create_vpc.custom_resolver_hub
}

output "dns_endpoint_gateways_by_id" {
  description = "The list of VPEs that are made available for DNS resolution in the created VPC. Only set if enable_hub is false and enable_hub_vpc_id are true."
  value       = module.create_vpc.dns_endpoint_gateways_by_id
}

output "dns_endpoint_gateways_by_crn" {
  description = "The list of VPEs that are made available for DNS resolution in the created VPC. Only set if enable_hub is false and enable_hub_vpc_id are true."
  value       = module.create_vpc.dns_endpoint_gateways_by_crn
}

##############################################################################
# Public Gateways
##############################################################################

output "public_gateways" {
  description = "Map of public gateways by zone"
  value       = module.create_vpc.public_gateways
}

##############################################################################
# Subnet Outputs
##############################################################################

output "subnet_ids" {
  description = "The IDs of the subnets"
  value       = module.create_vpc.subnet_ids[0]
}

output "subnet_detail_list" {
  description = "The IDs of the subnets"
  value       = module.create_vpc.subnet_detail_list[0]
}
