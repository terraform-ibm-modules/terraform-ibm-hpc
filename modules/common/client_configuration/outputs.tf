output "client_create_complete" {
  value       = true
  description = "Client cluster create complete"
  depends_on  = [resource.local_sensitive_file.write_client_meta_private_key, resource.null_resource.prepare_client_inventory_using_jumphost_connection, resource.null_resource.prepare_client_inventory, resource.null_resource.perform_client_configuration]
}
