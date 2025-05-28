output "bastion_vsi_data" {
  description = "Bastion VSI data"
  value       = module.bastion_vsi[*]
}

output "deployer_vsi_data" {
  description = "Deployer VSI data"
  value       = module.deployer_vsi[*]
}

output "bastion_primary_ip" {
  description = "Bastion primary IP"
  value       = var.bastion_instance_name != null && var.bastion_instance_public_ip != null ? data.ibm_is_instance.bastion_instance_name[0].primary_network_interface[0].primary_ip[0].address : one(module.bastion_vsi[*]["fip_list"][0]["ipv4_address"])
}

output "bastion_fip" {
  description = "Bastion FIP"
  value       = var.bastion_instance_public_ip != null && var.bastion_instance_name != null ? var.bastion_instance_public_ip : one(module.bastion_vsi[*]["fip_list"][0]["floating_ip"])
}

output "bastion_fip_id" {
  description = "Bastion FIP ID"
  value       = var.bastion_instance_name != null && var.bastion_instance_public_ip != null ? null : module.bastion_vsi[*]["fip_list"][0]["floating_ip_id"]
}

output "bastion_security_group_id" {
  description = "Bastion SG"
  value       = var.bastion_security_group_id != null ? var.bastion_security_group_id : one(module.bastion_sg[*].security_group_id)
}

output "bastion_security_group_id_for_ref" {
  description = "Bastion SG id for ref"
  value       = one(module.bastion_sg[*].security_group_id_for_ref)
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

output "bastion_private_key_content" {
  description = "Bastion private key content"
  sensitive   = true
  value       = one(module.ssh_key[*].private_key_content)
}
