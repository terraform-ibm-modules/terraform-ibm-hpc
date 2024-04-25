resource "ibm_resource_instance" "itself" {
  count             = var.dns_instance_id == "null" ? 1 : 0
  name              = format("%s-dns-instance", var.prefix)
  resource_group_id = var.resource_group_id
  location          = "global"
  service           = "dns-svcs"
  plan              = "standard-dns"
  tags              = local.tags
}

locals {
  dns_instance_id = var.dns_instance_id == "null" ? ibm_resource_instance.itself[0].guid : var.dns_instance_id
}

locals {
  name   = "hpc"
  prefix = var.prefix
  tags   = [local.prefix, local.name]
}

resource "ibm_dns_custom_resolver" "itself" {
  count             = var.dns_custom_resolver_id == "null" ? 1 : 0
  name              = format("%s-custom-resolver", var.prefix)
  instance_id       = local.dns_instance_id
  enabled           = true
  high_availability = length(var.subnets_crn) > 1 ? true : false
  dynamic "locations" {
    for_each = length(var.subnets_crn) > 3 ? slice(var.subnets_crn, 0, 2) : var.subnets_crn
    content {
      subnet_crn = locations.value
      enabled    = true
    }
  }
}

resource "ibm_dns_zone" "itself" {
  count       = 1
  instance_id = local.dns_instance_id
  name        = var.dns_domain_names[0]
}

data "ibm_dns_zones" "itself" {
  instance_id = local.dns_instance_id
  depends_on  = [ibm_dns_zone.itself]
}

locals {
  dns_zone_maps = [for zone in data.ibm_dns_zones.itself.dns_zones : {
    (zone["name"]) = zone["zone_id"]
  } if contains(var.dns_domain_names, zone["name"])]
}

resource "ibm_dns_permitted_network" "itself" {
  count       = 1
  instance_id = local.dns_instance_id
  vpc_crn     = var.vpc_crn
  zone_id     = split("/", ibm_dns_zone.itself[0].id)[1]
  type        = "vpc"
}
