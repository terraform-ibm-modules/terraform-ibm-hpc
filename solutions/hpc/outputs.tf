output "ssh_command" {
  description = "SSH command to connect to HPC cluster"
  value       = var.bastion_instance_public_ip != null ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${var.bastion_instance_public_ip} lsfadmin@${local.compute_hosts[0]}" : var.enable_fip ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.bootstrap.bastion_fip[0]} lsfadmin@${local.compute_hosts[0]}" : "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.bootstrap.bastion_primary_ip} lsfadmin@${local.compute_hosts[0]}"
}

output "bastion_primary_ip" {
  description = "Bastion Primary IP"
  value       = module.bootstrap.bastion_primary_ip
}

output "management_ssh" {
  description = "Management private IP"
  value       = local.management_private_ip
}

output "management_private_ip" {
  description = "IP of primary management node."
  value       = local.management_private_ip
}

output "management_candidate_private_ips" {
  description = "List of IPs of candidate management nodes."
  value       = local.management_candidate_private_ips
}

output "login_ssh" {
  description = "Login node private IP"
  value       = join(",", local.login_private_ips)
}

output "ldap_ssh" {
  description = "LDAP private IP"
  value       = join(",", local.ldap_private_ips)
}

output "ssh_to_ldap_node" {
  description = "SSH command to connect to LDAP node"
  value       = var.enable_ldap && var.ldap_server == "null" ? (var.enable_fip ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -J ubuntu@${module.bootstrap.bastion_fip[0]} ubuntu@${module.landing_zone_vsi.ldap_server}" : "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.bootstrap.bastion_primary_ip} ubuntu@${module.landing_zone_vsi.ldap_server}") : null
}

output "ssh_to_login_node" {
  description = "SSH command to connect to Login node"
  value       = var.bastion_instance_public_ip != null ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${var.bastion_instance_public_ip} lsfadmin@${join(",", local.login_private_ips)}" : var.enable_fip ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.bootstrap.bastion_fip[0]} lsfadmin@${join(",", local.login_private_ips)}" : "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.bootstrap.bastion_primary_ip} lsfadmin@${join(",", local.login_private_ips)}"
}

output "application_center_tunnel" {
  description = "Available if IBM Spectrum LSF Application Center GUI is installed"
  value       = var.enable_app_center ? local.ssh_cmd : null
}

output "application_center_url" {
  description = "Available if IBM Spectrum LSF Application Center GUI is installed"
  value       = var.enable_app_center ? var.app_center_high_availability ? "https://pac.${var.dns_domain_names.compute}:8443" : "https://localhost:8443" : null
}

output "application_center_url_note" {
  description = "Available if IBM Spectrum LSF Application Center GUI is installed in High Availability"
  value       = var.enable_app_center && var.app_center_high_availability ? "you may need '127.0.0.1 pac pac.${var.dns_domain_names.compute}' in your /etc/hosts, to let your browser use the ssh tunnel" : null
}

output "image_map_entry_found" {
  description = "Available if the image name provided is located within the image map"
  value       = module.landing_zone_vsi.image_map_entry_found
}

output "ldap_server" {
  description = "LDAP server"
  value       = module.landing_zone_vsi.ldap_server
}
output "subnet_crn" {
  description = "Subnets CRN"
  value       = local.subnets_crn
}

output "compute_crn" {
  description = "Compute subnets CRN"
  value       = local.compute_subnets[*].crn
}

output "file_share" {
  description = "VPC file share mount paths"
  value       = module.file_storage.mount_path
}

output "exclude_first_element" {
  description = "Mount paths excluding first element"
  value       = module.file_storage.mount_paths_excluding_first
}

output "mount_path_info" {
  description = "Mount paths information"
  value       = module.file_storage.mount_paths_info
}

output "bastion_fip" {
  description = "Bastion FIP"
  value       = module.bootstrap.bastion_fip
}

output "vpc_name" {
  description = "The VPC name in which the cluster resources have been deployed"
  value       = module.landing_zone.vpc_name
}

# ALB hostname output value
output "alb_hostname" {
  description = "ALB hostname: "
  value       = module.alb.alb_hostname
}
