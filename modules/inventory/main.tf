resource "local_sensitive_file" "itself" {
  content  = join("\n", concat([var.server_name, var.user], var.hosts))
  filename = var.inventory_path
}
