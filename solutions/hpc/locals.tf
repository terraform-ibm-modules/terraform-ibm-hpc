# locals needed for landing_zone
locals {
  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))
}

# locals needed for bootstrap
locals {
  # dependency: landing_zone -> bootstrap
  vpc_id                        = var.vpc == null ? one(module.landing_zone.vpc_id) : var.vpc
  bastion_subnets               = module.landing_zone.bastion_subnets
  boot_volume_encryption_key    = var.key_management != null ? one(module.landing_zone.boot_volume_encryption_key)["crn"] : null
  skip_iam_authorization_policy = true
}

# locals needed for landing_zone_vsi
locals {
  # dependency: landing_zone -> bootstrap -> landing_zone_vsi
  bastion_security_group_id  = module.bootstrap.bastion_security_group_id
  bastion_public_key_content = module.bootstrap.bastion_public_key_content

  # dependency: landing_zone -> landing_zone_vsi
  login_subnets    = module.landing_zone.login_subnets
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
  default_share = length(var.management_instances) > 0 ? [
    {
      mount_path = "/mnt/lsf"
      size       = 100
    }
  ] : []
  total_shares = length(var.management_instances) > 0 ? [] : concat(local.default_share, var.file_shares)
  file_shares = [
    for count in range(length(local.total_shares)) :
    {
      name = element(split("/", local.total_shares[count]["mount_path"]), length(split("/", local.total_shares[count]["mount_path"])) - 1)
      size = local.total_shares[count]["size"]
    }
  ]
}

# locals needed for file-storage
locals {
  # dependency: landing_zone -> file-storage
  resource_group_id = one(values(one(module.landing_zone.resource_group_id)))
  vpc_crn           = var.vpc == null ? one(module.landing_zone.vpc_crn) : one(data.ibm_is_vpc.itself[*].crn)
  subnets           = flatten([local.compute_subnets, local.storage_subnets, local.protocol_subnets])
  subnets_crns      = data.ibm_is_subnet.itself[*].crn
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
  compute_instances  = flatten([module.landing_zone_vsi.management_vsi_data, module.landing_zone_vsi.compute_vsi_data])
  storage_instances  = flatten([module.landing_zone_vsi.storage_vsi_data, module.landing_zone_vsi.protocol_vsi_data])
  protocol_instances = flatten([module.landing_zone_vsi.protocol_vsi_data])

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
  compute_hosts          = local.compute_instances[*]["ipv4_address"]
  storage_hosts          = local.storage_instances[*]["ipv4_address"]
  compute_inventory_path = "compute.ini"
  storage_inventory_path = "storage.ini"
}

# locals needed for playbook
locals {
  bastion_fip              = module.bootstrap.bastion_fip
  compute_private_key_path = "compute_id_rsa" #checkov:skip=CKV_SECRET_6
  storage_private_key_path = "storage_id_rsa" #checkov:skip=CKV_SECRET_6
  compute_playbook_path    = "compute_ssh.yaml"
  storage_playbook_path    = "storage_ssh.yaml"
}
