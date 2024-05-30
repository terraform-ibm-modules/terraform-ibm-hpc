output "my_cidr" {
  value       = data.external.my_ipv4.result.ip != "" ? ["${data.external.my_ipv4.result.ip}/32"] : []
  description = "The IPv4 in CIDR format (a '/32' is appended)"
}
