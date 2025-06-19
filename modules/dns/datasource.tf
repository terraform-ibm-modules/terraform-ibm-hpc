# data "ibm_dns_zones" "conditional" {
#   count       = var.dns_instance_id != null ? 1 : 0
#   instance_id = var.dns_instance_id
# }

data "ibm_dns_zones" "dns_zones" {
  instance_id = local.dns_instance_id
  depends_on  = [ibm_dns_zone.dns_zone]
}
