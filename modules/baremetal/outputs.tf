output "list" {
  description = "A list of Bare Metal servers with id, name, IP, and VNI ID"
  value = [
    for key, server in module.storage_baremetal : {
      id           = server.bms_server_id
      name         = server.bms_server_name
      ipv4_address = server.bms_server_ip
      vni_id       = server.bms_vni_id
    }
  ]
}
