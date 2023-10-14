output "hpc_basic_example_output" {
  value       = module.hpc-basic-example
  sensitive   = true
  description = "SSH command to connect to HPC cluster"
}