output "lsf" {
  value = module.lsf.file_storage
  #sensitive = true
}

output "deployer" {
  value = module.lsf.deployer
  # sensitive = true
}


output "hostname" {
  value = module.lsf.hostname
  #sensitive = true
}