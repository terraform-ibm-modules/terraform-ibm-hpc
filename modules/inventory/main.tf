resource "local_sensitive_file" "itself" {
  content  = join("\n", var.hosts)
  filename = var.inventory_path
}
