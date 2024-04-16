resource "ibm_dns_resource_record" "a" {
  count       = length(var.dns_records)
  instance_id = var.dns_instance_id
  zone_id     = var.dns_zone_id
  type        = "A"
  name        = var.dns_records[count.index]["name"]
  rdata       = var.dns_records[count.index]["rdata"]
  ttl         = 300
}
###########################
# TODO: on line number30 update the var.dns_domain_names to pick up existing domain name when we support scale/protocol domain names
##########################

resource "ibm_dns_resource_record" "ptr" {
  count       = length(var.dns_records)
  instance_id = var.dns_instance_id
  zone_id     = var.dns_zone_id
  type        = "PTR"
  name        = var.dns_records[count.index]["rdata"]
  rdata       = format("%s.%s", var.dns_records[count.index]["name"], var.dns_domain_names["compute"])
  #rdata      = format("%s.%s", var.dns_records[count.index]["name"], one(local.dns_domain_name))
  ttl        = 300
  depends_on = [ibm_dns_resource_record.a]
}
