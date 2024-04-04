output "db_instance_info" {
  value = {
    id            = module.db.id
    adminuser     = module.db.adminuser
    adminpassword = var.adminpassword
    hostname      = module.db.hostname
    port          = module.db.port
    certificate   = module.db.certificate_base64
  }
}
