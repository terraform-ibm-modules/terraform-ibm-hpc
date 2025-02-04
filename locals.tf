# locals needed for landing_zone
locals {
  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))

  # SSH key calculations
  # Combining the common ssh keys with host specific ssh keys
  bastion_ssh_keys = distinct(concat(coalesce(var.bastion_ssh_keys, []), coalesce(var.ssh_keys, [])))
  storage_ssh_keys = distinct(concat(coalesce(var.storage_ssh_keys, []), coalesce(var.ssh_keys, [])))
  compute_ssh_keys = distinct(concat(coalesce(var.compute_ssh_keys, []), coalesce(var.ssh_keys, [])))
  client_ssh_keys  = distinct(concat(coalesce(var.client_ssh_keys, []), coalesce(var.ssh_keys, [])))
}


# locals needed for deployer
locals {
  # dependency: landing_zone -> deployer
  vpc_id                     = var.vpc == null ? one(module.landing_zone.vpc_id) : var.vpc
  bastion_subnets            = module.landing_zone.bastion_subnets
  kms_encryption_enabled     = var.key_management != null ? true : false
  boot_volume_encryption_key = var.key_management != null ? one(module.landing_zone.boot_volume_encryption_key)["crn"] : null
  existing_kms_instance_guid = var.key_management != null ? module.landing_zone.key_management_guid : null

  # Future use
  # skip_iam_authorization_policy = true
}


# locals needed for landing_zone_vsi
locals {
  # dependency: landing_zone -> deployer -> landing_zone_vsi
  bastion_security_group_id  = module.deployer.bastion_security_group_id
  bastion_public_key_content = module.deployer.bastion_public_key_content

  # dependency: landing_zone -> landing_zone_vsi
  client_subnets   = module.landing_zone.client_subnets
  compute_subnets  = module.landing_zone.compute_subnets
  storage_subnets  = module.landing_zone.storage_subnets
  protocol_subnets = module.landing_zone.protocol_subnets

  #boot_volume_encryption_key = var.key_management != null ? one(module.landing_zone.boot_volume_encryption_key)["crn"] : null
  #skip_iam_authorization_policy = true
  #resource_group_id = data.ibm_resource_group.itself.id
  #vpc_id            = var.vpc == null ? module.landing_zone.vpc_id[0] : data.ibm_is_vpc.itself[0].id
  #vpc_crn           = var.vpc == null ? module.landing_zone.vpc_crn[0] : data.ibm_is_vpc.itself[0].crn
}

# locals needed for file-storage
locals {
  # dependency: landing_zone -> file-storage
  #vpc_id                        = var.vpc == null ? one(module.landing_zone.vpc_id) : var.vpc
  #boot_volume_encryption_key    = var.key_management != null ? one(module.landing_zone.boot_volume_encryption_key)["crn"] : null

  # dependency: landing_zone_vsi -> file-share
  compute_subnet_id         = local.compute_subnets[0].id
  compute_security_group_id = module.landing_zone_vsi.compute_sg_id
  management_instance_count = sum(var.management_instances[*]["count"])
  default_share = local.management_instance_count > 0 ? [
    {
      mount_path = "/mnt/lsf"
      size       = 100
      iops       = 1000
    }
  ] : []
  storage_instance_count = sum(var.storage_instances[*]["count"])
  total_shares           = local.storage_instance_count > 0 ? concat(local.default_share, var.file_shares) : []
  # fileset_size_map = try({ for details in var.filesets : details.mount_path => details.size }, {})
  file_shares = [
    for count in range(length(local.total_shares)) :
    {
      name = format("%s-%s", var.prefix, element(split("/", local.total_shares[count]["mount_path"]), length(split("/", local.total_shares[count]["mount_path"])) - 1))
      size = local.total_shares[count]["size"]
      iops = local.total_shares[count]["iops"]
    }
  ]
}

# locals needed for DNS
locals {
  # dependency: landing_zone -> DNS
  resource_group_id = one(values(one(module.landing_zone.resource_group_id)))
  vpc_crn           = var.vpc == null ? one(module.landing_zone.vpc_crn) : one(data.ibm_is_vpc.itself[*].crn)
  # TODO: Fix existing subnet logic
  #subnets_crn       = var.vpc == null ? module.landing_zone.subnets_crn : ###
  #subnets           = flatten([local.compute_subnets, local.storage_subnets, local.protocol_subnets])
  #subnets_crns      = data.ibm_is_subnet.itself[*].crn
  subnets_crn = module.landing_zone.subnets_crn
  #boot_volume_encryption_key    = var.key_management != null ? one(module.landing_zone.boot_volume_encryption_key)["crn"] : null

  # dependency: landing_zone_vsi -> file-share
}

# locals needed for dns-records
locals {
  # dependency: dns -> dns-records
  dns_instance_id = module.dns.dns_instance_id
  compute_dns_zone_id = one(flatten([
    for dns_zone in module.dns.dns_zone_maps : values(dns_zone) if one(keys(dns_zone)) == var.dns_domain_names["compute"]
  ]))
  storage_dns_zone_id = one(flatten([
    for dns_zone in module.dns.dns_zone_maps : values(dns_zone) if one(keys(dns_zone)) == var.dns_domain_names["storage"]
  ]))
  protocol_dns_zone_id = one(flatten([
    for dns_zone in module.dns.dns_zone_maps : values(dns_zone) if one(keys(dns_zone)) == var.dns_domain_names["protocol"]
  ]))

  # dependency: landing_zone_vsi -> dns-records
  compute_instances                     = flatten([module.landing_zone_vsi.management_vsi_data, module.landing_zone_vsi.compute_vsi_data])
  storage_instances                     = flatten([module.landing_zone_vsi.storage_vsi_data, module.landing_zone_vsi.protocol_vsi_data])
  storage_management_instances          = flatten([module.landing_zone_vsi.storage_management_vsi_data])
  protocol_instances                    = flatten([module.landing_zone_vsi.protocol_vsi_data])
  afm_instances                         = flatten([module.landing_zone_vsi.afm_vsi_data])
  gklm_instances                        = flatten([module.landing_zone_vsi.gklm_vsi_data])
  ldap_instances                        = flatten(module.landing_zone_vsi.ldap_vsi_data)
  storage_cluster_tie_breaker_instances = flatten(module.landing_zone_vsi.storage_cluster_tie_breaker_vsi_data)
  total_compute_cluster_instances       = sum(var.static_compute_instances[*]["count"])
  total_storage_cluster_instances       = sum(var.storage_instances[*]["count"])
  enable_afm                            = sum(var.afm_instances[*]["count"]) > 0 ? true : false

  compute_dns_records = [
    for instance in local.compute_instances :
    {
      name  = instance["name"]
      rdata = instance["ipv4_address"]
    }
  ]
  storage_dns_records = [
    for instance in local.storage_instances :
    {
      name  = instance["name"]
      rdata = instance["ipv4_address"]
    }
  ]
  protocol_dns_records = [
    for instance in local.protocol_instances :
    {
      name  = instance["name"]
      rdata = instance["ipv4_address"]
    }
  ]
}

# locals needed for inventory
locals {
  scale_version             = "5.2.1.1"
  compute_hosts_private_ids = flatten(local.compute_instances[*]["ipv4_address"])
  compute_hosts_ids         = flatten(local.compute_instances[*]["id"])
  compute_hosts_names       = flatten(local.compute_instances[*]["name"])

  storage_hosts_private_ids = flatten(local.storage_instances[*]["ipv4_address"])
  storage_hosts_ids         = flatten(local.storage_instances[*]["id"])
  storage_hosts_names       = flatten(local.storage_instances[*]["name"])

  secondary_compute_hosts_private_ids = flatten(local.compute_instances[*]["secondary_ipv4_address"])
  secondary_storage_hosts_private_ids = flatten(local.storage_instances[*]["secondary_ipv4_address"])


  ldap_private_ips = local.ldap_instances[*]["ipv4_address"]
  ldap_hostnames   = local.ldap_instances[*]["name"]


  afm_hosts_private_ips = flatten(local.afm_instances[*]["ipv4_address"])
  afm_hosts_ids         = flatten(local.afm_instances[*]["id"])
  afm_hosts_names       = flatten(local.afm_instances[*]["name"])

  gklm_hosts_private_ips = flatten(local.gklm_instances[*]["ipv4_address"])
  gklm_hosts_ids         = flatten(local.gklm_instances[*]["id"])
  gklm_hosts_names       = flatten(local.gklm_instances[*]["name"])

  protocol_hosts_private_ips = flatten(local.protocol_instances[*]["ipv4_address"])
  protocol_hosts_ids         = flatten(local.protocol_instances[*]["id"])
  protocol_hosts_names       = flatten(local.protocol_instances[*]["name"])

  storage_management_hosts_private_ips = flatten(local.storage_management_instances[*]["ipv4_address"])
  storage_management_hosts_ids         = flatten(local.storage_management_instances[*]["id"])
  storage_management_hosts_names       = flatten(local.storage_management_instances[*]["name"])

  storage_cluster_tie_breaker_instances_hosts_private_ips = flatten(local.storage_cluster_tie_breaker_instances[*]["ipv4_address"])
  storage_cluster_tie_breaker_instances_hosts_ids         = flatten(local.storage_cluster_tie_breaker_instances[*]["id"])
  storage_cluster_tie_breaker_instances_hosts_names       = flatten(local.storage_cluster_tie_breaker_instances[*]["name"])


  compute_inventory_path = "compute.ini"
  storage_inventory_path = "storage.ini"
}

locals {
  storage_instance_ids         = var.storage_type != "persistent" ? local.enable_afm == true ? concat(local.storage_hosts_ids, local.afm_hosts_ids) : local.storage_hosts_ids : []
  storage_instance_names       = var.storage_type != "persistent" ? local.enable_afm == true ? concat(local.storage_hosts_names, local.afm_hosts_names) : local.storage_hosts_names : []
  storage_instance_private_ips = var.storage_type != "persistent" ? local.enable_afm == true ? concat(local.storage_hosts_private_ids, local.afm_hosts_private_ips) : local.storage_hosts_private_ids : []
  # storage_instance_private_dns_ip_map = var.storage_type != "persistent" ? one(module.storage_cluster_instances[*].instance_private_dns_ip_map) : {}

  storage_cluster_instance_ids         = local.scale_ces_enabled == false ? local.storage_instance_ids : concat(local.storage_instance_ids, local.protocol_hosts_ids)
  storage_cluster_instance_names       = local.scale_ces_enabled == false ? local.storage_instance_names : concat(local.storage_instance_names, local.protocol_hosts_names)
  storage_cluster_instance_private_ips = local.scale_ces_enabled == false ? local.storage_instance_private_ips : concat(local.storage_instance_private_ips, local.protocol_hosts_private_ips)
  # storage_cluster_instance_private_dns_ip_map = local.scale_ces_enabled == false ? local.storage_instance_private_dns_ip_map : merge(local.storage_instance_private_dns_ip_map, one(module.protocol_cluster_instances[*].instance_private_dns_ip_map))

  tie_breaker_storage_instance_ids         = var.storage_type != "persistent" ? flatten(local.storage_cluster_tie_breaker_instances_hosts_ids) : []
  tie_breaker_storage_instance_names       = var.storage_type != "persistent" ? flatten(local.storage_cluster_tie_breaker_instances_hosts_names) : []
  tie_breaker_storage_instance_private_ips = var.storage_type != "persistent" ? flatten(local.storage_cluster_tie_breaker_instances_hosts_private_ips) : []
  # tie_breaker_storage_instance_private_dns_ip_map = var.storage_type != "persistent" ? one(module.storage_cluster_tie_breaker_instance[*].instance_private_dns_ip_map) : {}
}

# locals needed for playbook
locals {
  bastion_fip              = module.deployer.bastion_fip
  bastion_instance_id      = module.deployer.bastion_vsi_data[*]["fip_list"][0]["floating_ip"]
  compute_private_key_path = "compute_id_rsa" #checkov:skip=CKV_SECRET_6
  storage_private_key_path = "storage_id_rsa" #checkov:skip=CKV_SECRET_6
  bastion_private_key_path = "bastion_id_rsa" #checkov:skip=CKV_SECRET_6
  ldap_private_key_path    = "ldap_id_rsa"    #checkov:skip=CKV_SECRET_6
  compute_playbook_path    = "compute_ssh.yaml"
  storage_playbook_path    = "storage_ssh.yaml"
}


# locals {
#   gpfs_base_rpm_path = fileset(var.spectrumscale_rpms_path, "gpfs.base-*")
#   scale_org_version  = regex("gpfs.base-(.*).x86_64.rpm", tolist(local.gpfs_base_rpm_path)[0])[0]
#   scale_version      = replace(local.scale_org_version, "-", ".")
# }

locals {
  client_instance_count = sum(var.client_instances[*]["count"])
  # management_instance_count     = sum(var.management_instances[*]["count"])
  # storage_instance_count        = sum(var.storage_instances[*]["count"])
  protocol_instance_count       = sum(var.protocol_instances[*]["count"])
  static_compute_instance_count = sum(var.static_compute_instances[*]["count"])
  afm_instance_count            = sum(var.afm_instances[*]["count"])
}

locals {
  compute_vsi_profile    = var.static_compute_instances[*]["profile"]
  storage_vsi_profile    = var.storage_instances[*]["profile"]
  management_vsi_profile = var.management_instances[*]["profile"]
  afm_vsi_profile        = var.afm_instances[*]["profile"]
  protocol_vsi_profile   = var.protocol_instances[*]["profile"]
  afm_server_type        = strcontains(local.afm_vsi_profile[0], "metal")
  ces_server_type        = strcontains(local.protocol_vsi_profile[0], "metal")
}

locals {
  scale_ces_enabled            = local.protocol_instance_count > 0 ? true : false
  is_colocate_protocol_subset  = local.scale_ces_enabled && var.colocate_protocol_cluster_instances ? local.protocol_instance_count < local.total_storage_cluster_instances ? true : false : false
  enable_sec_interface_compute = local.scale_ces_enabled == false && data.ibm_is_instance_profile.compute_profile.bandwidth[0].value >= 64000 ? true : false
  enable_sec_interface_storage = local.scale_ces_enabled == false && var.storage_type != "persistent" && data.ibm_is_instance_profile.storage_profile.bandwidth[0].value >= 64000 ? true : false
  enable_mrot_conf             = local.enable_sec_interface_compute && local.enable_sec_interface_storage ? true : false
}



output "file_shares" {
  value = local.file_shares
}
