/*
output "landing-zone" {
  value = module.landing-zone
}

output "bootstrap" {
  value     = module.bootstrap
  sensitive = true
}

output "landing-zone-vsi" {
  value = module.landing-zone-vsi
}
*/
# output "ssh_command" {
#   description = "SSH command to connect to HPC cluster"
#   value       = var.enable_bastion ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.bastion.bastion_fip} vpcuser@${local.compute_hosts[0]}" : null
# }
