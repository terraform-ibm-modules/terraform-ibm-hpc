# output "vpc_dns" {
#   description = "List of VPC DNS details for each of the VPCs."
#   value = [
#     for vpc in module.vpc :
#     {
#       dns_instance_id        = vpc.dns_instance_id
#       dns_custom_resolver_id = vpc.dns_custom_resolver_id
#       dns_zone_state         = vpc.dns_zone_state
#       dns_zone_id            = vpc.dns_zone_id
#       dns_zone               = vpc.dns_zone
#       dns_record_ids         = vpc.dns_record_ids
#     }
#   ]
# }


output "dns_instance_id" {
  description = "dns_instance_id"
  value       = module.landing_zone_dns[*].vpc_dns[0].dns_instance_id
}

output "dns_custom_resolver_id" {
  description = "dns_custom_resolver_id"
  value       = module.landing_zone_dns[*].vpc_dns[0].dns_custom_resolver_id
}

output "dns_zone_id" {
  description = "dns_zone_id"
  value       = module.landing_zone_dns[*].vpc_dns[0].dns_zone_id
}
