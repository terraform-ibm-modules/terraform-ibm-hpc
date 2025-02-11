output "db_instance_info" {
  description = "Database instance information"
  value = {
    id          = module.db.id
    admin_user  = module.db.adminuser
    hostname    = module.db.hostname
    port        = module.db.port
    certificate = module.db.certificate_base64
  }
}

output "db_admin_password" {
  description = "Database instance password"
  value       = var.admin_password
  sensitive   = true
}
