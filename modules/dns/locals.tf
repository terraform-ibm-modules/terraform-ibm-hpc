locals {
  dns_zone_maps = [for zone in data.ibm_dns_zones.dns_zones.dns_zones : {
    (zone["name"]) = zone["zone_id"]
  } if contains(var.dns_domain_names, zone["name"])]

  dns_instance_id = var.dns_instance_id == null ? ibm_resource_instance.resource_instance[0].guid : var.dns_instance_id
}
