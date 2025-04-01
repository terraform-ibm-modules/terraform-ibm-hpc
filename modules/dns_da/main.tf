# resource "ibm_resource_instance" "resource_instance" {
#   count             = var.dns_instance_id == null ? 1 : 0
#   name              = format("%s-dns-instance", var.prefix)
#   resource_group_id = var.resource_group_id
#   location          = "global"
#   service           = "dns-svcs"
#   plan              = "standard-dns"
# }

# resource "ibm_dns_custom_resolver" "dns_custom_resolver" {
#   count             = var.dns_custom_resolver_id == null ? 1 : 0
#   name              = format("%s-custom-resolver", var.prefix)
#   instance_id       = local.dns_instance_id
#   enabled           = true
#   high_availability = length(var.subnets_crn) > 1 ? true : false
#   dynamic "locations" {
#     for_each = length(var.subnets_crn) > 3 ? slice(var.subnets_crn, 0, 3) : var.subnets_crn
#     content {
#       subnet_crn = locations.value
#       enabled    = true
#     }
#   }
# }

# resource "ibm_dns_zone" "dns_zone" {
#   count       = length(local.dns_domain_names)
#   instance_id = local.dns_instance_id
#   name        = local.dns_domain_names[count.index]
# }

# resource "ibm_dns_permitted_network" "dns_permitted_network" {
#   count       = length(var.dns_domain_names)
#   instance_id = local.dns_instance_id
#   vpc_crn     = var.vpc_crn
#   zone_id     = one(values(local.dns_zone_maps[count.index]))
#   type        = "vpc"
# }



module "landing_zone_dns" {
  source                         = "terraform-ibm-modules/landing-zone/ibm"
  version                        = "7.4.2"
  prefix                         = var.prefix
  vpcs                           = local.vpcs
  ssh_keys                       = local.ssh_keys
  virtual_private_endpoints      = local.virtual_private_endpoints
  clusters                       = local.clusters
  transit_gateway_resource_group = local.transit_gateway_resource_group
  vsi                            = local.vsi
  key_management                 = local.key_management
  atracker                       = local.atracker
  region                         = local.region
  resource_groups                = local.resource_groups
  transit_gateway_connections    = local.transit_gateway_connections
  cos                            = local.cos
  vpn_gateways                   = local.vpn_gateways
}
