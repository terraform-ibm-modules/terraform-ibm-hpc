# module "storage_key" {
#   count  = local.enable_storage ? 1 : 0
#   source = "./../key"
# }

module "storage_baremetal" {
  source                       = "terraform-ibm-modules/bare-metal-vpc/ibm"
  version                      = "1.2.0"
  count                        = length(var.storage_servers)
  server_count                 = var.storage_servers[count.index]["count"]
  prefix                       = var.prefix
  profile                      = var.storage_servers[count.index]["profile"]
  image_id                     = var.image_id
  create_security_group        = false
  subnet_ids                   = var.storage_subnets
  ssh_key_ids                  = var.storage_ssh_keys
  bandwidth                    = var.sapphire_rapids_profile_check == true ? 200000 : 100000
  allowed_vlan_ids             = var.allowed_vlan_ids
  access_tags                  = null
  resource_group_id            = var.existing_resource_group
  security_group_ids           = var.security_group_ids
  user_data                    = var.user_data
  secondary_vni_enabled        = var.secondary_vni_enabled
  secondary_subnet_ids         = length(var.protocol_subnets) == 0 ? [] : [var.protocol_subnets[0].id]
  secondary_security_group_ids = var.security_group_ids
  tpm_mode                     = "tpm_2"
}


resource "time_sleep" "wait_for_reboot_tolerate" {
  count           = var.bms_boot_drive_encryption == true ? 1 : 0
  create_duration = "400s"
  depends_on      = [module.storage_baremetal]
}

resource "null_resource" "scale_boot_drive_reboot_tolerate_provisioner" {
  for_each = var.bms_boot_drive_encryption == false ? {} : {
    for idx, count_number in range(local.storage_server_count) : idx => {
      network_ip = element(local.bm_serve_ips, idx)
    }
  }
  connection {
    type        = "ssh"
    host        = each.value.network_ip
    user        = "root"
    private_key = var.storage_private_key_content
    timeout     = "60m"
  }

  provisioner "remote-exec" {
    inline = [
      "while true; do",
      "  lsblk | grep crypt",
      "  if [[ \"$?\" -eq 0 ]]; then",
      "    break",
      "  fi",
      "  echo \"Waiting for BMS to be rebooted and drive to get encrypted...\"",
      "  sleep 10",
      "done",
      "lsblk",
      "systemctl restart NetworkManager",
      "echo \"Restarted NetworkManager\""
    ]
  }
  depends_on = [time_sleep.wait_for_reboot_tolerate]
}
