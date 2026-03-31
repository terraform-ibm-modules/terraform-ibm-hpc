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
  value       = var.enable_fip ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vpcuser@${local.packer_floating_ip}" : null
}

output "packer_vsi_debug_instructions" {
  description = "Instructions to monitor and debug the custom image build process"

  value = var.enable_fip ? (
    <<EOT
To monitor and debug the custom image build process:

1. SSH into the deployer VSI:
   ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vpcuser@${local.packer_floating_ip}

2. Monitor build progress using logs:

   - Cloud-init logs (instance initialization phase):
     sudo tail -f /var/log/cloud-init-output.log

   - Packer execution logs (provisioning phase):
     sudo tail -f /var/log/packer.log

3. HPC setup validation summary:

   - The file /var/log/hpc_summary.log is generated during execution of the base setup script (script.sh).
   - This file is finalized only after script.sh completes execution within the Packer provisioning phase.
   - It may not be immediately available if provisioning is still in progress.

   To view once available:
     cat /var/log/hpc_summary.log

   - This summary includes validation results for default image configuration (script.sh).
   - Customizations performed via customer_script.sh are NOT included in this report.

4. Post-build artifact:

   - After successful completion of the Packer build, hpc_summary.log is automatically downloaded to the deployer vsi.
   - This downloaded copy represents the final validated state of the image.

5. Quick validation check:

   grep FAILED /var/log/hpc_summary.log || echo "No failures detected"

EOT
  ) : "Floating IP not enabled; SSH access unavailable."
}
