output "landing_zone" {
  description = "Landing Zone data"
  value       = module.landing_zone
}

output "deployer" {
  description = "Deployer data"
  value       = module.deployer
  sensitive   = true
}

output "landing_zone_vsi" {
  description = "Landing Zone VSI data"
  value       = module.landing_zone_vsi
  sensitive   = true
}

output "dns" {
  description = "DNS data"
  value       = module.dns
}

output "file_storage" {
  description = "File Storage data"
  value       = module.file_storage
}

output "ssh_to_deployer" {
  description = "SSH command to connect to the deployer"
  value       = var.enable_deployer && var.enable_bastion ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.deployer.bastion_fip} vpcuser@${module.deployer.deployer_ip}" : null
}

output "ssh_to_storage" {
  description = "SSH command to connect to the storage cluster"
  value       = var.storage_instances[0]["count"] != 0 && var.enable_bastion ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.deployer.bastion_fip} vpcuser@${local.storage_hosts[0]}" : null
}

# output "ssh_to_compute" {
#   description = "SSH command to connect to the compute cluster"
#   value       = (var.management_instances[0]["count"] != 0 || var.static_compute_instances[0]["count"] != 0) && var.enable_bastion ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.deployer.bastion_fip} vpcuser@${local.compute_hosts[0]}" : null
# }
