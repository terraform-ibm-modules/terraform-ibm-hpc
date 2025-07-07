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
  value       = var.remote_allowed_ips
}

output "ssh_to_deployer" {
  description = "SSH command to connect to the deployer"
  value       = (var.enable_deployer == false) ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${var.bastion_fip} vpcuser@${var.deployer_ip}" : null
}

output "ssh_to_management_node" {
  description = "SSH command to connect to the management node"
  value       = var.scheduler == "LSF" && (var.enable_deployer == false) && length(local.mgmt_hosts_ips) > 0 ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@${var.bastion_fip} vpcuser@${local.mgmt_hosts_ips[0]}" : null
}

output "cloud_monitoring_url" {
  value       = var.observability_monitoring_enable && (var.enable_deployer == false) ? module.cloud_monitoring_instance_creation[0].cloud_monitoring_url : null
  description = "IBM Cloud Monitoring URL"
}

output "cloud_logs_url" {
  value       = (var.enable_deployer == false) && (var.observability_logs_enable_for_management || var.observability_logs_enable_for_compute) ? module.cloud_monitoring_instance_creation[0].cloud_logs_url : null
  description = "IBM Cloud Logs URL"
}
