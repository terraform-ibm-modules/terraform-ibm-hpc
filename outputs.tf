output "ssh_command" {
  description = "SSH command to connect to HPC cluster"
  value       = module.hpc.ssh_command
}

output "resource_group_id" {
  description = "Resource group ID"
  value       = module.hpc.resource_group_id
}