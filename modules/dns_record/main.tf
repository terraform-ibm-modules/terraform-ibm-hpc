resource "ibm_dns_resource_record" "a" {
  for_each    = local.dns_records_map
  instance_id = var.dns_instance_id
  zone_id     = var.dns_zone_id
  type        = "A"
  name        = each.value.name
  rdata       = each.value.rdata
  ttl         = 60
}

resource "ibm_dns_resource_record" "ptr" {
  for_each    = local.dns_records_map
  instance_id = var.dns_instance_id
  zone_id     = var.dns_zone_id
  type        = "PTR"
  name        = each.value.rdata
  rdata       = format("%s.%s", each.value.name, one(local.dns_domain_name))
  ttl         = 60
  depends_on  = [ibm_dns_resource_record.a]
}
