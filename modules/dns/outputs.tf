output "dns_instance_id" {
  description = "DNS instance ID"
  value       = local.dns_instance_id
}

#output "dns_custom_resolver_id" {
#  description = "DNS custom resolver ID"
#  value       = var.dns_custom_resolver_id == null ? one(ibm_dns_custom_resolver.itself[*].id) : var.dns_custom_resolver_id
#}

output "dns_zone_maps" {
  description = "DNS zones"
  value       = local.dns_zone_maps
}
