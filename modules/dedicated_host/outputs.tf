##############################################################################
# Outputs
##############################################################################

output "dedicated_host_id" {
  value       = module.dedicated_host.dedicated_host_ids
  description = "List the Dedicated Host ID's"
}

output "dedicated_host_group_id" {
  value       = module.dedicated_host.dedicated_host_group_ids
  description = "List the Dedicated Host Group ID's"
}
