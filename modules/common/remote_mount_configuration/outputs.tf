
output "remote_mount_create_complete" {
  value       = true
  depends_on  = [time_sleep.wait_for_gui_db_initialization, null_resource.prepare_remote_mnt_inventory, null_resource.prepare_remote_mnt_inventory_using_jumphost_connection, null_resource.perform_scale_deployment]
  description = "Remote mount create complete"
}
