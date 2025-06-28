output "reserved_ips_details" {
  value       = try(toset([for instance_details in ibm_is_subnet_reserved_ip.itself : instance_details]), [])
  description = "Reserved ip details."
}

output "instance_name_ip_map" {
  value       = try({ for instance_details in ibm_is_subnet_reserved_ip.itself : "${instance_details.name}.${var.protocol_domain}" => instance_details.address }, {})
  description = "Instance name and ip map"
  depends_on  = [ibm_dns_resource_record.a_itself, ibm_dns_resource_record.ptr_itself]
}

output "reserved_ip_id_ip_map" {
  value       = try({ for reserved_ip_details in ibm_is_subnet_reserved_ip.itself : reserved_ip_details.name => reserved_ip_details.reserved_ip }, {})
  description = "Reserved name and its ip map"
  depends_on  = [ibm_dns_resource_record.a_itself, ibm_dns_resource_record.ptr_itself]
}
