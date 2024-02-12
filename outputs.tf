###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

output "region_name" {
  value = data.ibm_is_region.region.name
}

output "image_entry_found" {
  value = module.hpc.image_map_entry_found
}

output "vpc_name" {
  value = "${data.ibm_is_vpc.vpc.name} --  - ${data.ibm_is_vpc.vpc.id}"
}

output "ssh_to_management_node" {
  description = "SSH command to connect to HPC cluster"
  value       = module.hpc.ssh_command
}

output "ssh_to_ldap_node" {
  value = module.hpc.ssh_to_ldap_node
}

output "ssh_to_login_node" {
  value = module.hpc.ssh_to_login_node
}

output "application_center" {
  value = module.hpc.application_center
}

output "application_center_url" {
  value = var.enable_app_center ? "https://localhost:8443" : null
}

# output "bastion_fip" {
#   value = module.hpc.bastion_fip
# }

# output "login_ssh" {
#   value = module.hpc.login_ssh
# }

# output "ldap_ssh" {
#   value = module.hpc.ldap_ssh
# }
# output "mount_path_info" {
#   value = module.hpc.mount_path_info
# }

# output "local_fileshare" {
#   value = module.hpc.local_check
# }

# output "use_public_gateways" {
#   value = module.hpc.use_public_gateways
# }

# output "map" {
#   value = module.hpc.map
# }

# output "public_gateways" {
#   value       = module.hpc.public_gateways
# }

# output "test" {
#   value = local.prefixes_in_given_zone_1
#   # value       = module.hpc.vpc_name
# }