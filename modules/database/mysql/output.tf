output "db_instance_info" {
  value = {
    id            = ibm_database.itself.id
    adminuser     = ibm_database.itself.adminuser
    adminpassword = ibm_database.itself.adminpassword
    hostname      = data.ibm_database_connection.db_connection.mysql[0].hosts[0].hostname
    port          = data.ibm_database_connection.db_connection.mysql[0].hosts[0].port
    certificate   = data.ibm_database_connection.db_connection.mysql[0].certificate[0].certificate_base64
  }
}
