output "list" {
  description = "A list of VSI with name, id, zone, and primary ipv4 address"
  value = flatten([
    for module_instance in module.storage_baremetal : [
      for server_key, server_details in module_instance.baremetal_servers :
      {
        id                      = server_details.bms_server_id
        name                    = server_details.bms_server_name
        ipv4_address            = try(server_details.bms_server_primary_ip, null)
        bms_primary_vni_id      = try(server_details.bms_primary_vni_id, null)
        bms_server_secondary_ip = try(server_details.bms_server_secondary_ip, null)
        bms_secondary_vni_id    = try(server_details.bms_secondary_vni_id, null)
      }
    ]
  ])
  depends_on = [module.storage_baremetal]
}

output "instance_ips_with_vol_mapping" {
  value       = { for instance_details in local.bm_server_name : instance_details => local.selected_disks }
  description = "Instance ips with vol mapping"
}
