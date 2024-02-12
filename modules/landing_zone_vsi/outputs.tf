# output "login_vsi_data" {
#   description = "Login VSI data"
#   value       = module.login_vsi[*]["list"]
# }

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

output "image_map_entry_found" {
  value = "${local.image_mapping_entry_found} --  - ${var.management_image_name}"
}

output "ldap_server" {
  value = local.ldap_server
}
# output "compute_vsi_data" {
#   description = "Compute VSI data"
#   value       = module.compute_vsi[*]["list"]
# }

# output "storage_vsi_data" {
#   description = "Storage VSI data"
#   value       = module.storage_vsi[*]["list"]
# }

# output "protocol_vsi_data" {
#   description = "Protocol VSI data"
#   value       = module.protocol_vsi[*]["list"]
# }

output "compute_sg_id" {
  description = "Compute SG id"
  value       = module.compute_sg[*].security_group_id
}

output "compute_public_key_content" {
  value     = one(module.compute_key[*].private_key_content)
  sensitive = true
}

output "compute_private_key_content" {
  value     = one(module.compute_key[*].private_key_content)
  sensitive = true
}
