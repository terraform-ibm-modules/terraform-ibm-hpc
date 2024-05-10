output "region_name" {
  description = "The region name in which the cluster resources have been deployed"
  value       = data.ibm_is_region.region.name
}

output "image_entry_found" {
  description = "Available if the image name provided is located within the image map"
  value       = module.hpc.image_map_entry_found
}

output "vpc_name" {
  description = "The VPC name in which the cluster resources have been deployed"
  value       = "${data.ibm_is_vpc.vpc.name} --  - ${data.ibm_is_vpc.vpc.id}"
}

output "ssh_to_management_node_1" {
  description = "SSH command to connect to HPC cluster"
  value       = module.hpc.ssh_command
}

output "ssh_to_ldap_node" {
  description = "SSH command to connect to LDAP node"
  value       = module.hpc.ssh_to_ldap_node
}

output "ssh_to_login_node" {
  description = "SSH command to connect to Login node"
  value       = module.hpc.ssh_to_login_node
}

output "application_center_tunnel" {
  description = "Available if IBM Spectrum LSF Application Center GUI is installed"
  value       = module.hpc.application_center_tunnel
}

output "application_center_url" {
  description = "Available if IBM Spectrum LSF Application Center GUI is installed"
  value       = module.hpc.application_center_url
}

output "application_center_url_note" {
  description = "Available if IBM Spectrum LSF Application Center GUI is installed in High Availability"
  value       = module.hpc.application_center_url_note
}