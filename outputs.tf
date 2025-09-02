#############################################
###            Common Outputs             ###
#############################################

output "region_name" {
  description = "The region name in which the cluster resources have been deployed"
  value       = local.region
}

output "vpc_name" {
  description = "The VPC name in which the cluster resources have been deployed"
  value       = local.vpc_name
}

output "remote_allowed_cidr" {
  description = "The following IPs/networks are allow-listed for incoming connections"
  value       = join(", ", var.remote_allowed_ips)
}

#############################################
###            LSF Output                 ###
#############################################

output "image_details" {
  description = "The image details used for deploying cluster resources"
  value       = var.scheduler == "LSF" && var.enable_deployer == false ? format("LSF Version: %s | Management Image: %s", var.lsf_version, var.management_instances[0].image) : null
}

output "ssh_to_management_node" {
  description = "SSH command to connect to the management node"
  value       = var.scheduler == "LSF" && (var.enable_deployer == false) && length(local.mgmt_hosts_ips) > 0 ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${var.bastion_fip} vpcuser@${local.mgmt_hosts_ips[0]}" : null
}

output "ssh_to_login_node" {
  description = "SSH command to connect to the Login node"
  value       = var.scheduler == "LSF" && (var.enable_deployer == false) ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${var.bastion_fip} lsfadmin@${local.login_host_ip[0]}" : null
}


output "cloud_monitoring_url" {
  value       = var.scheduler == "LSF" && var.observability_monitoring_enable && (var.enable_deployer == false) ? module.cloud_monitoring_instance_creation[0].cloud_monitoring_url : null
  description = "IBM Cloud Monitoring URL"
}

output "cloud_logs_url" {
  value       = var.scheduler == "LSF" && (var.enable_deployer == false) && (var.observability_logs_enable_for_management || var.observability_logs_enable_for_compute) ? module.cloud_monitoring_instance_creation[0].cloud_logs_url : null
  description = "IBM Cloud Logs URL"
}

output "application_center_tunnel" {
  description = "Available if IBM Spectrum LSF Application Center GUI is installed"
  value       = var.scheduler == "LSF" && (var.enable_deployer == false) ? local.ssh_cmd : null
}

output "application_center_url" {
  description = "Available if IBM Spectrum LSF Application Center GUI is installed"
  value       = var.scheduler == "LSF" ? "https://localhost:8443" : null
}

#############################################
###            Scale Outputs              ###
#############################################

output "scale_version" {
  description = "Version of Scale"
  value       = var.scheduler == "Scale" ? local.scale_version : null
}

#############################################
###            Common Outputa             ###
#############################################

output "ssh_to_deployer" {
  description = "SSH command to connect to the deployer"
  value       = (var.enable_deployer == false) ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${var.bastion_fip} vpcuser@${var.deployer_ip}" : null
}

output "ssh_to_ldap_node" {
  description = "SSH command to connect to LDAP node"
  value       = (var.enable_deployer == false && var.enable_ldap && length(local.ldap_hosts_ips) > 0) ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -J ubuntu@${var.bastion_fip} ubuntu@${local.ldap_hosts_ips[0]}" : null
}
