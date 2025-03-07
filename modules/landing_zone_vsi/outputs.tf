output "client_vsi_data" {
  description = "client VSI data"
  value       = module.client_vsi[*]["list"]
}

output "management_vsi_data" {
  description = "Management VSI data"
  value       = module.management_vsi[*]["list"]
}

output "compute_vsi_data" {
  description = "Compute VSI data"
  value       = module.compute_vsi[*]["list"]
}

output "storage_vsi_data" {
  description = "Storage VSI data"
  value       = module.storage_vsi[*]["list"]
}

output "protocol_vsi_data" {
  description = "Protocol VSI data"
  value       = module.protocol_vsi[*]["list"]
}

output "compute_sg_id" {
  description = "Compute SG id"
  value       = module.compute_sg[*].security_group_id
}

output "compute_public_key_content" {
  description = "Compute public key content"
  sensitive   = true
  value       = one(module.compute_key[*].public_key_content)
}

output "compute_private_key_content" {
  description = "Compute private key content"
  sensitive   = true
  value       = one(module.compute_key[*].private_key_content)
}
