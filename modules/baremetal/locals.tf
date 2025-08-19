# define variables
locals {
#  storage_image_id = data.ibm_is_image.storage[*].id
  # resource_group_id = data.ibm_resource_group.existing_resource_group.id
  # bms_interfaces    = ["ens1", "ens2"]
  # bms_interfaces = ["eth0", "eth1"]
  # storage_ssh_keys  = [for name in var.storage_ssh_keys : data.ibm_is_ssh_key.storage[name].id]

  # TODO: explore (DA always keep it true)
  #skip_iam_authorization_policy = true
  #storage_server_count = sum(var.storage_servers[*]["count"])
  #enable_storage       = local.storage_server_count > 0

  raw_bm_details = flatten([
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

  bm_server_name = flatten(local.raw_bm_details[*].name)
  #  bm_serve_ips   = flatten([for server in local.raw_bm_details : server[*].ipv4_address])

  disk0_interface_type = (data.ibm_is_bare_metal_server_profile.itself[*].disks[0].supported_interface_types[0].default)[0]
  disk_count           = (data.ibm_is_bare_metal_server_profile.itself[*].disks[1].quantity[0].value)[0]

  # Determine starting disk based on disk0 interface type
  nvme_start_disk = local.disk0_interface_type == "sata" ? "0" : "1"

  # Generate NVMe device list up to 36 disks
  all_disks = [
    "/dev/nvme0n1", "/dev/nvme1n1", "/dev/nvme2n1", "/dev/nvme3n1", "/dev/nvme4n1", "/dev/nvme5n1",
    "/dev/nvme6n1", "/dev/nvme7n1", "/dev/nvme8n1", "/dev/nvme9n1", "/dev/nvme10n1", "/dev/nvme11n1",
    "/dev/nvme12n1", "/dev/nvme13n1", "/dev/nvme14n1", "/dev/nvme15n1", "/dev/nvme16n1", "/dev/nvme17n1",
    "/dev/nvme18n1", "/dev/nvme19n1", "/dev/nvme20n1", "/dev/nvme21n1", "/dev/nvme22n1", "/dev/nvme23n1",
    "/dev/nvme24n1", "/dev/nvme25n1", "/dev/nvme26n1", "/dev/nvme27n1", "/dev/nvme28n1", "/dev/nvme29n1",
    "/dev/nvme30n1", "/dev/nvme31n1", "/dev/nvme32n1", "/dev/nvme33n1", "/dev/nvme34n1", "/dev/nvme35n1"
  ]

  # Select only the required number of disks
  selected_disks = slice(local.all_disks, local.nvme_start_disk, local.disk_count + local.nvme_start_disk)
}
