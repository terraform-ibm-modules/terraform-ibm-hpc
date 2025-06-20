output "write_inventory_complete" {
  description = "Write Inventory Complete"
  value       = true
  depends_on  = [local_sensitive_file.infra_details_to_json]
}
