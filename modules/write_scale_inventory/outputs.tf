output "write_scale_inventory_complete" {
  value      = true
  depends_on = [local_sensitive_file.itself]
}