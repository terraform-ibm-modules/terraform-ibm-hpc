output "region_name" {
  description = "The region name in which the cluster resources have been deployed"
  value       = data.ibm_is_region.region.name
}

output "image_entry_found" {
  description = "Available if the image name provided is located within the image map"
  value       = module.landing_zone_vsi[0].image_map_entry_found
}

output "vpc_name" {
  description = "The VPC name in which the cluster resources have been deployed"
  value       = "${data.ibm_is_vpc.vpc.name} --  - ${data.ibm_is_vpc.vpc.id}"
}

output "ssh_to_management_node_1" {
  description = "SSH command to connect to HPC cluster"
  value       = local.bastion_instance_public_ip != null ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${local.bastion_instance_public_ip} lsfadmin@${local.compute_hosts[0]}" : var.enable_fip ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.bootstrap[0].bastion_fip[0]} lsfadmin@${local.compute_hosts[0]}" : "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.bootstrap[0].bastion_primary_ip} lsfadmin@${local.compute_hosts[0]}"
}

output "ssh_to_ldap_node" {
  description = "SSH command to connect to LDAP node"
  value       = var.enable_ldap && var.ldap_server == "null" ? (var.enable_fip ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -J ubuntu@${module.bootstrap[0].bastion_fip[0]} ubuntu@${module.landing_zone_vsi[0].ldap_server}" : "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.bootstrap[0].bastion_primary_ip} ubuntu@${module.landing_zone_vsi[0].ldap_server}") : null
}

output "ssh_to_login_node" {
  description = "SSH command to connect to Login node"
  value       = local.bastion_instance_public_ip != null ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${local.bastion_instance_public_ip} lsfadmin@${join(",", local.login_private_ips)}" : var.enable_fip ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.bootstrap[0].bastion_fip[0]} lsfadmin@${join(",", local.login_private_ips)}" : "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${module.bootstrap[0].bastion_primary_ip} lsfadmin@${join(",", local.login_private_ips)}"
}

output "application_center_tunnel" {
  description = "Available if IBM Spectrum LSF Application Center GUI is installed"
  value       = var.enable_app_center ? local.ssh_cmd : null
}

output "application_center_url" {
  description = "Available if IBM Spectrum LSF Application Center GUI is installed"
  value       = var.enable_app_center ? var.app_center_high_availability ? "https://pac.${var.dns_domain_name.compute}:8443" : "https://localhost:8443" : null
}

output "application_center_url_note" {
  description = "Available if IBM Spectrum LSF Application Center GUI is installed in High Availability"
  value       = var.enable_app_center && var.app_center_high_availability ? "you may need '127.0.0.1 pac pac.${var.dns_domain_name.compute}' on /etc/hosts of your local machine where the connection is established, to let your browser use the ssh tunnel" : null
}

output "remote_allowed_cidr" {
  description = "The following IPs/networks are allow-listed for incoming connections"
  value       = local.allowed_cidr
}

output "management_hostname" {
  description = "Management node has this hostname:"
  value       = local.print_extra_outputs ? local.management_hostname : null
}

output "management_ip" {
  description = "Management node has this IP:"
  value       = local.print_extra_outputs ? local.management_private_ip : null
}

output "management_candidate_hostnames" {
  description = "Management candidate nodes have these hostnames:"
  value       = local.print_extra_outputs ? local.management_candidate_hostnames : null
}

output "management_candidate_ips" {
  description = "Management candidate nodes have these IPs:"
  value       = local.print_extra_outputs ? local.management_candidate_private_ips : null
}

output "login_hostnames" {
  description = "Login nodes have these hostnames:"
  value       = local.print_extra_outputs ? local.login_hostnames : null
}

output "login_ips" {
  description = "Login nodes have these IPs:"
  value       = local.print_extra_outputs ? local.login_private_ips : null
}

output "ldap_hostnames" {
  description = "LDAP nodes have these hostnames:"
  value       = local.print_extra_outputs ? local.ldap_hostnames : null
}

output "ldap_ips" {
  description = "LDAP nodes have these IPs:"
  value       = local.print_extra_outputs ? local.ldap_private_ips : null
}

output "cloud_monitoring_url" {
  value       = var.observability_monitoring_enable ? module.cloud_monitoring_instance_creation.cloud_monitoring_url : null
  description = "IBM Cloud Monitoring URL"
}

output "cloud_logs_url" {
  value       = (var.observability_logs_enable_for_management || var.observability_logs_enable_for_compute) ? module.cloud_monitoring_instance_creation.cloud_logs_url : null
  description = "IBM Cloud Logs URL"
}

output "worker_node_min_count" {
  description = "Provides the total number of count for the static worker node."
  value       = local.total_worker_node_count
}
