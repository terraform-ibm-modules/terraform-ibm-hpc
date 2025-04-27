output "list" {
  value       = [for m in module.storage_baremetal : m.baremetal_servers]
  description = "List of Bare Metal Server IDs and Names"
}
