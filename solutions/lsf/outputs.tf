output "lsf" {
  description = "LSF details"
  value       = module.lsf.file_storage
}

# output "ssh_to_compute" {
#   value = module.lsf.ssh_to_compute
#   #sensitive = true
# }

# output "lsf_all" {
#   value = module.lsf
# }
