output "management_vsi_data" {
  description = "Management VSI data"
  value       = module.management_vsi[*]["list"]
}

output "management_candidate_vsi_data" {
  description = "Management candidate VSI data"
  value       = module.management_candidate_vsi[*]["list"]
}

output "login_vsi_data" {
  description = "Login VSI data"
  value       = module.login_vsi[*]["list"]
}

output "ldap_vsi_data" {
  description = "Login VSI data"
  value       = module.ldap_vsi[*]["list"]
}

output "worker_vsi_data" {
  description = "Static worker VSI data"
  value       = module.worker_vsi[*]["list"]
}

output "image_map_entry_found" {
  description = "Available if the image name provided is located within the image map"
  value       = "${local.image_mapping_entry_found} --  - ${var.management_image_name}"
}

output "ldap_server" {
  description = "LDAP server IP"
  value       = local.ldap_server
}

output "compute_sg_id" {
  description = "Compute SG id"
  value       = module.compute_sg[*].security_group_id
}

output "compute_public_key_content" {
  description = "Compute public key content"
  value       = one(module.compute_key[*].private_key_content)
  sensitive   = true
}

output "compute_private_key_content" {
  description = "Compute private key content"
  value       = one(module.compute_key[*].private_key_content)
  sensitive   = true
}
