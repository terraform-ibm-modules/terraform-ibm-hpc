output "record" {
  value = local.dns_domain_name
}

output "dns_record" {
  value = data.ibm_dns_zones.itself
}