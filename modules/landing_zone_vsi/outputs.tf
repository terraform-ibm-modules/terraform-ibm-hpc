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

output "compute_management_vsi_data" {
  description = "Compute Management VSI data"
  value       = module.compute_cluster_management_vsi[*]["list"]
}

output "storage_vsi_data" {
  description = "Storage VSI data"
  value       = module.storage_vsi[*]["list"]
}

output "storage_cluster_management_vsi" {
  description = "Storage Management VSI data"
  value       = module.storage_cluster_management_vsi[*]["list"]
}

output "protocol_vsi_data" {
  description = "Protocol VSI data"
  value       = module.protocol_vsi[*]["list"]
}

output "compute_sg_id" {
  description = "Compute SG id"
  value       = module.compute_sg[*].security_group_id
}

output "afm_vsi_data" {
  description = "AFM VSI data"
  value       = module.afm_vsi[*]["list"]
}

output "gklm_vsi_data" {
  description = "GKLM VSI data"
  value       = module.gklm_vsi[*]["list"]
}

output "ldap_vsi_data" {
  description = "LDAP VSI data"
  value       = module.ldap_vsi[*]["list"]
}

output "storage_cluster_tie_breaker_vsi_data" {
  description = "Storage Cluster Tie Breaker VSI data"
  value       = module.storage_cluster_tie_breaker_vsi[*]["list"]
}

output "instance_ips_with_vol_mapping" {
  value = try({ for instance_details in flatten([for name_details in (flatten(module.storage_vsi[*]["list"])[*]["name"]): name_details]): instance_details =>
  data.ibm_is_instance_profile.storage[0].disks[0].quantity[0].value == 1 ? ["/dev/vdb"] : ["/dev/vdb", "/dev/vdc"] }, {})
}

output "instance_ips_with_vol_mapping_tie_breaker" {
  value = try({ for instance_details in flatten([for name_details in (flatten(module.storage_cluster_tie_breaker_vsi[*]["list"])[*]["name"]): name_details]) : instance_details =>
  data.ibm_is_instance_profile.storage_tie_instance[0].disks[0].quantity[0].value == 1 ? ["/dev/vdb"] : ["/dev/vdb", "/dev/vdc"] }, {})
}

output "storage_private_key_content" {
  value = try(module.storage_key[0].private_key_content, "")
  sensitive = true
}

output "storage_public_key_content" {
  value = try(module.storage_key[0].public_key_content, "")
  sensitive = true
}
