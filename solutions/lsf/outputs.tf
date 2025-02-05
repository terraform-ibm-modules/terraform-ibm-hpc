output "lsf" {
  value = module.lsf.file_storage
  #sensitive = true
}

# output "subnet_crnn" {
#   value = module.lsf.subnet_crnn
#   # sensitive = true
# }


output "subnets_crn" {
  value = module.lsf.subnets_crn
  sensitive = true
}