locals {
  dns_domain_name = [
    for zone in data.ibm_dns_zones.dns_zones.dns_zones : zone["name"] if zone["zone_id"] == var.dns_zone_id
  ]
}
