output "vpc_id" {
  description = "The VPC ID in which the packer resources have been deployed"
  value       = data.ibm_is_vpc.vpc.id
}

output "subnet_id" {
  description = "The Subnet ID in which the packer resources have been deployed"
  value       = var.subnet_id == null ? local.landing_zone_subnet_output[0].id : var.subnet_id
}

output "packer_vsi_name" {
  description = "Packer VSI name"
  value       = local.packer_vsi_name
}

output "ssh_to_packer_vsi" {
  description = "SSH command to connect to the packer VSI"
  value       = var.enable_fip ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${local.packer_floating_ip}" : null
}
