output "bastion_primary_ip" {
  description = "Bastion primary IP"
  value       = var.bastion_instance_name != null && var.bastion_instance_public_ip != null ? data.ibm_is_instance.bastion_instance_name[0].primary_network_interface[0].primary_ip[0].address : one(module.bastion_vsi[*]["fip_list"][0]["ipv4_address"])
}

output "bastion_fip" {
  description = "Bastion FIP"
  value       = var.bastion_instance_public_ip != null && var.bastion_instance_name != null ? [var.bastion_instance_public_ip] : module.bastion_vsi[*]["fip_list"][0]["floating_ip"]
}

output "bastion_fip_id" {
  description = "Bastion FIP ID"
  value       = var.bastion_instance_name != null && var.bastion_instance_public_ip != null ? null : one(module.bastion_vsi[*]["fip_list"][0]["floating_ip_id"])
}

output "bastion_security_group_id" {
  description = "Bastion SG"
  value       = var.bastion_security_group_id != null ? var.bastion_security_group_id : one(module.bastion_sg[*].security_group_id)
}

output "bastion_public_key_content" {
  description = "Bastion public key content"
  sensitive   = true
  value       = one(module.ssh_key[*].public_key_content)
}

output "bastion_private_key_content" {
  description = "Bastion private key content"
  sensitive   = true
  value       = one(module.ssh_key[*].private_key_content)
}
