output "storage_cluster_create_complete" {
  value       = true
  depends_on  = [time_sleep.wait_60_seconds, null_resource.wait_for_ssh_availability, null_resource.prepare_ansible_inventory, null_resource.prepare_ansible_inventory_using_jumphost_connection, null_resource.prepare_ansible_inventory_encryption, null_resource.prepare_ansible_inventory_using_jumphost_connection_encryption, null_resource.perform_scale_deployment]
  description = "Storage cluster create complete"
}
