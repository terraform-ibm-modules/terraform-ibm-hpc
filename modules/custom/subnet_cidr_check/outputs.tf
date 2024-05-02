output "results" {
  description = "Result of the calculation"
  value       = [for ip in local.vpc_address_prefix : ip[0] <= local.subnet_cidr[0][0] && ip[1] >= local.subnet_cidr[0][1]]
}
