# Create a map keyed by record name (or use rdata if that is unique)
locals {
  dns_map = { for r in var.dns_records :
    r.name => {
      name  = r.name
      rdata = r.rdata
    }
  }
}

resource "ibm_dns_resource_record" "a" {
  for_each    = local.dns_map
  instance_id = var.dns_instance_id
  zone_id     = var.dns_zone_id
  type        = "A"
  name        = each.value.name
  rdata       = each.value.rdata
  ttl         = 300
}

resource "ibm_dns_resource_record" "ptr" {
  for_each    = local.dns_map
  instance_id = var.dns_instance_id
  zone_id     = var.dns_zone_id
  type        = "PTR"
  name        = each.value.rdata
  rdata       = "${each.value.name}.${one(local.dns_domain_name)}"
  ttl         = 300

  depends_on = [ibm_dns_resource_record.a]
}
