resource "ibm_resource_instance" "itself" {
  count             = var.dns_instance_id == null ? 1 : 0
  name              = format("%s-dns-instance", var.prefix)
  resource_group_id = var.resource_group_id
  location          = "global"
  service           = "dns-svcs"
  plan              = "standard-dns"
}

locals {
  dns_instance_id = var.dns_instance_id == null ? ibm_resource_instance.itself[0].guid : var.dns_instance_id
}

resource "ibm_dns_custom_resolver" "itself" {
  count             = var.dns_custom_resolver_id == null ? 1 : 0
  name              = format("%s-custom-resolver", var.prefix)
  instance_id       = local.dns_instance_id
  enabled           = true
  high_availability = length(var.subnets_crn) > 1 ? true : false
  dynamic "locations" {
    for_each = length(var.subnets_crn) > 3 ? slice(var.subnets_crn, 0, 3) : var.subnets_crn
    content {
      subnet_crn = locations.value
      enabled    = true
    }
  }
}

data "ibm_dns_zones" "conditional" {
  count       = var.dns_instance_id != null ? 1 : 0
  instance_id = var.dns_instance_id
}

locals {
  dns_domain_names = flatten([setsubtract(var.dns_domain_names == null ? [] : var.dns_domain_names, flatten(data.ibm_dns_zones.conditional[*].dns_zones[*]["name"]))])
}

resource "ibm_dns_zone" "itself" {
  count       = length(local.dns_domain_names)
  instance_id = local.dns_instance_id
  name        = local.dns_domain_names[count.index]
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
  count       = length(var.dns_domain_names)
  instance_id = local.dns_instance_id
  vpc_crn     = var.vpc_crn
  zone_id     = one(values(local.dns_zone_maps[count.index]))
  type        = "vpc"
}
