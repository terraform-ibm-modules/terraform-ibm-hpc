/*
output "bastion_vsi_data" {
  value = module.bastion_vsi[*]
}
*/

output "bootstrap_vsi_data" {
  description = "Bootstrap VSI Data"
  value       = module.bootstrap_vsi[*]["list"]
}
