output "landing_zone" {
  value = module.landing_zone
}

output "deployer" {
  value     = flatten(module.deployer.deployer_vsi_data[*].list)
  # sensitive = true
}

output "landing_zone_vsi" {
  value = module.landing_zone_vsi
}

output "dns" {
  value = module.dns
}

output "file_storage" {
  value = local.deployer_instances
}

output "subnets_crn" {
  value = local.subnets_crn
}

# output "subnet_crnn" {
#   value = local.subnets_crnn
# }



# output "existing_compute_subnets" {
#   value = local.existing_compute_subnets
# }

# output "existing_compute_subnets_details" {
#   value = data.ibm_is_subnet.existing_compute_subnets
# }

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
