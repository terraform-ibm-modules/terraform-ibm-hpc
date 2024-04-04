/*
output "landing-zone" {
  value = module.landing-zone
}

output "bootstrap" {
  value     = module.bootstrap
  sensitive = true
}

output "landing-zone-vsi" {
  value = module.landing-zone-vsi
}
*/

output "ssh_command" {
  description = "SSH command to connect to HPC cluster"
  value       = var.enable_fip ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J vpcuser@${module.bootstrap.bastion_fip} lsfadmin@${local.compute_hosts[0]}" : "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J vpcuser@${module.bootstrap.bastion_primary_ip} lsfadmin@${local.compute_hosts[0]}"
}

output "bastion_primary_ip" {
  value = module.bootstrap.bastion_primary_ip
}

output "management_ssh" {
  value = local.management_private_ip
}
output "login_ssh" {
  value = join(",", local.login_private_ips)
}

output "ldap_ssh" {
  value = join(",", local.ldap_private_ips)
}

output "ssh_to_ldap_node" {
  value = var.enable_ldap && var.ldap_server == "null" ? (var.enable_fip ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -J vpcuser@${module.bootstrap.bastion_fip} ubuntu@${module.landing_zone_vsi.ldap_server}" : "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J vpcuser@${module.bootstrap.bastion_primary_ip} ubuntu@${module.landing_zone_vsi.ldap_server}") : null
}

output "ssh_to_login_node" {
  value = var.enable_fip ? "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J vpcuser@${module.bootstrap.bastion_fip} lsfadmin@${join(",", local.login_private_ips)}" : "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J vpcuser@${module.bootstrap.bastion_primary_ip} lsfadmin@${join(",", local.login_private_ips)}"
}

output "application_center_tunnel" {
  value = var.app_center_high_availability || var.enable_app_center ? local.ssh_cmd : null
}

output "application_center_url" {
  value = var.app_center_high_availability ? "https://pac.${var.dns_domain_names.compute}:8443" : (var.enable_app_center ? "https://localhost:8443" : null)
}

output "application_center_url_NOTE" {
  value = var.app_center_high_availability ? "you may need '127.0.0.1 pac pac.${var.dns_domain_names.compute}' in your /etc/hosts, to let your browser use the ssh tunnel" : null
}

output "image_map_entry_found" {
  value = module.landing_zone_vsi.image_map_entry_found
}

output "ldap_server" {
  value = module.landing_zone_vsi.ldap_server
}
output "subnet_crn" {
  value = local.subnets_crn
}

output "compute_crn" {
  value = local.compute_subnets[*].crn
}

output "dns_check" {
  value = module.compute_dns_records.check_dns
}

output "file_share" {
  value = module.file_storage.mount_path
}

output "exclude_first_element" {
  value = module.file_storage.mount_paths_excluding_first
}

output "mount_path_info" {
  value = module.file_storage.mount_paths_info
}

output "local_check" {
  value = local.file_shares
}

# output "use_public_gateways" {
#   value = module.landing_zone.use_public_gateways
# }

# output "map" {
#   value = module.landing_zone.map
# }

# output "public_gateways" {
#   value       = module.landing_zone.public_gateways
# }

output "bastion_fip" {
  value = module.bootstrap.bastion_fip
}
# output "test" {
#   # value = "${local.validate_private_subnet_cidr_1} + ${local.validate_private_subnet_cidr_2} + ${module.ipvalidation_cluster_subnet[0].results} + ${length(var.subnet_id) != 0}"
#   value = local.prefixes_in_given_zone_1
# }

output "vpc_name" {
  value = module.landing_zone.vpc_name
}

# ALB hostname output value
output "alb_hostname" {
  description = "ALB hostname: "
  value       = module.alb.alb_hostname
}
#
#output "dns_reserved_ip" {
#  value = local.dns_reserved_ip
#}
#
#output "dns_service_id" {
#  value = local.dns_service_id
#}
#
#output "dns_instance_ids" {
#  value = local.dns_instance_ids
#}
#
#output "reserved_ip" {
#  value = data.ibm_is_subnet_reserved_ips.dns_reserved_ips
#}
#
#output "resolver_id" {
#  value = local.resolver_id
#}
#
#output "sagar_check" {
#  value = local.sagar_check
#}
#
#output "dns_instance_id" {
#  value = local.dns_instance_id
#}
