# output "lsf" {
#   value = module.lsf.file_storage
#   #sensitive = true
# }

output "ssh_to_compute" {
  value = module.lsf.ssh_to_compute
  #sensitive = true
}

output "lsf" {
  value = module.lsf
}