output "ssh_command" {
  description = "SSH command to connect to HPC cluster"
  value       = module.hpc.ssh_command
}
