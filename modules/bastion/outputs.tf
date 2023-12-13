output "bastion_fip" {
  description = "Bastion FIP"
  value       = one(module.bastion_vsi[*]["fip_list"][0]["floating_ip"])
}

output "bastion_security_group_id" {
  description = "Bastion SG"
  value       = one(module.bastion_sg[*].security_group_id)
}

output "bastion_ssh_keys" {
  description = "Bastion SSH Keys"
  value       = local.bastion_ssh_keys
}

output "bastion_public_key_content" {
  description = "Bastion public key content"
  sensitive   = false
  value       = one(module.ssh_key[*].public_key_content)
}

output "bastion_private_key_content" {
  description = "Bastion private key content"
  sensitive   = false
  value       = one(module.ssh_key[*].private_key_content)
}
