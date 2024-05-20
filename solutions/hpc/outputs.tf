output "region_name" {
  description = "The region name in which the cluster resources have been deployed"
  value       = data.ibm_is_region.region.name
}

output "image_entry_found" {
  description = "Available if the image name provided is located within the image map"
  value       = module.landing_zone_vsi.image_map_entry_found
}

output "vpc_name" {
  description = "The VPC name in which the cluster resources have been deployed"
  value       = "${data.ibm_is_vpc.vpc.name} --  - ${data.ibm_is_vpc.vpc.id}"
}

output "ssh_to_management_node_1" {
  description = "SSH command to connect to HPC cluster"
  value       = local.bastion_instance_public_ip != null ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${local.bastion_instance_public_ip} lsfadmin@${local.compute_hosts[0]}" : var.enable_fip ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.bootstrap.bastion_fip[0]} lsfadmin@${local.compute_hosts[0]}" : "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.bootstrap.bastion_primary_ip} lsfadmin@${local.compute_hosts[0]}"
}

output "ssh_to_ldap_node" {
  description = "SSH command to connect to LDAP node"
  value       = var.enable_ldap && var.ldap_server == "null" ? (var.enable_fip ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -J ubuntu@${module.bootstrap.bastion_fip[0]} ubuntu@${module.landing_zone_vsi.ldap_server}" : "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.bootstrap.bastion_primary_ip} ubuntu@${module.landing_zone_vsi.ldap_server}") : null
}

output "ssh_to_login_node" {
  description = "SSH command to connect to Login node"
  value       = local.bastion_instance_public_ip != null ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${local.bastion_instance_public_ip} lsfadmin@${join(",", local.login_private_ips)}" : var.enable_fip ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.bootstrap.bastion_fip[0]} lsfadmin@${join(",", local.login_private_ips)}" : "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.bootstrap.bastion_primary_ip} lsfadmin@${join(",", local.login_private_ips)}"
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
