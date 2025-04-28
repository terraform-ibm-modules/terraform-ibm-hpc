output "list" {
  description = "A list of VSI with name, id, zone, and primary ipv4 address"
  value = flatten([
    for module_instance in module.storage_baremetal : [
      for server_key, server_details in module_instance.baremetal_servers :
      {
        id           = server_details.bms_server_id
        name         = server_details.bms_server_name
        ipv4_address = server_details.bms_server_ip
        vni_id       = server_details.bms_vni_id
      }
    ]
  ])
}
