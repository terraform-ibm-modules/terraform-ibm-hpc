output "bastion_vsi_data" {
  description = "Bastion VSI data"
  value       = module.bastion_vsi[*]
}

output "deployer_vsi_data" {
  description = "Deployer VSI data"
  value       = module.deployer_vsi[*]
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

output "deployer_ip" {
  description = "Deployer IP"
  value       = one(module.deployer_vsi[*]["list"][0]["ipv4_address"])
}

output "deployer_ip_new" {
  description = "Deployer IP"
  value       = one(module.deployer_vsi[*])
}

output "bastion_private_key_content" {
  description = "Bastion private key content"
  sensitive   = true
  value       = one(module.ssh_key[*].private_key_content)
}
