locals {
  dns_instance_name              = format("%s-dns-instance", var.prefix)
  dns_custom_resolver_name       = format("%s-custom-resolver", var.prefix)
  ssh_keys                       = []
  virtual_private_endpoints      = []
  clusters                       = []
  transit_gateway_resource_group = null
  vsi                            = []
  key_management                 = {}
  atracker                       = {}
  region                         = null
  resource_groups                = []
  transit_gateway_connections    = []
  cos                            = []
  vpn_gateways                   = []
  enable_hub                     = true
  vpcs = [
    {
      existing_vpc_id           = var.vpc_name == null ? null : data.ibm_is_vpc.existing_vpc[0].id
      dns_instance_name         = local.dns_instance_name
      dns_custom_resolver_name  = local.dns_custom_resolver_name
      dns_location              = "global"
      dns_plan                  = "standard-dns"
      enable_hub                = true
      dns_zone_name             = var.dns_zone_name
      dns_records               = var.dns_records
      existing_dns_instance_id  = var.existing_dns_instance_id ? var.existing_dns_instance_id : ""
      use_existing_dns_instance = var.use_existing_dns_instance ? var.existing_dns_instance_id : ""




    }
  ]
  #   vpcs = [
  #     {
  #       prefix = var.prefix

  #     }
  #   ]
}
