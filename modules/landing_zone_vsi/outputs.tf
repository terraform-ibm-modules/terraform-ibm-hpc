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

output "afm_vsi_data" {
  description = "AFM VSI data"
  value       = module.afm_vsi[*]["list"]
}

output "compute_sg_id" {
  description = "Compute SG id"
  value       = module.compute_sg[*].security_group_id
}

output "ldap_vsi_data" {
  description = "LDAP VSI data"
  value       = module.ldap_vsi[*]["list"]
}

output "gklm_vsi_data" {
  description = "GKLM VSI data"
  value       = module.gklm_vsi[*]["list"]
}

output "storage_management_vsi_data" {
  description = "GKLM VSI data"
  value       = module.storage_cluster_management_vsi[*]["list"]
}

output "storage_cluster_tie_breaker_vsi_data" {
  description = "Storage Cluster Tie Breaker VSI data"
  value       = module.storage_cluster_tie_breaker_vsi[*]["list"]
}
