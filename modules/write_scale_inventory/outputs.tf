output "write_scale_inventory_complete" {
  value       = true
  description = "Scale inventory creation Complete."
  depends_on  = [local_sensitive_file.itself]
}
