/*
output "bastion_vsi_data" {
  value = module.bastion_vsi[*]
}
*/

output "bootstrap_vsi_data" {
  description = "Bootstrap VSI Data"
  value = module.bootstrap_vsi[*]["list"]
}

output "bastion_fip" {
  description = "Bastion FIP"
  value       = one(module.bastion_vsi[*]["fip_list"][0]["floating_ip"])
}

output "bastion_security_group_id" {
  description = "Bastion SG"
  value       = one(module.bastion_sg[*].security_group_id)
}

output "bastion_public_key_content" {
  description = "Bastion public key content"
  sensitive   = true
  value       = one(module.ssh_key[*].public_key_content)
}
