# locals needed for landing_zone
locals {
  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))
}

# locals needed for bootstrap
locals {
  # dependency: landing_zone -> bootstrap
  vpc_id                     = var.vpc == null ? one(module.landing_zone.vpc_id) : data.ibm_is_vpc.itself[0].id
  vpc                        = var.vpc == null ? one(module.landing_zone.vpc_name) : var.vpc
  bastion_subnets            = module.landing_zone.bastion_subnets
  kms_encryption_enabled     = var.key_management != null ? true : false
  boot_volume_encryption_key = var.key_management != null ? (var.boot_volume_encryption_key != null ? var.boot_volume_encryption_key : one(module.landing_zone.boot_volume_encryption_key)["crn"]) : null
  existing_kms_instance_guid = var.key_management != null ? one(module.landing_zone.key_management_guid) : null
  # Future use
  # skip_iam_authorization_policy = true
}

# locals needed for landing_zone_vsi
locals {
  # dependency: landing_zone -> bootstrap -> landing_zone_vsi
  bastion_security_group_id  = var.bastion_security_group_id != null ? var.bastion_security_group_id : module.bastion.bastion_security_group_id
  bastion_public_key_content = var.bastion_public_key_content != null ? var.bastion_public_key_content : module.bastion.bastion_public_key_content
  bastion_ssh_keys = module.bastion.bastion_ssh_keys

  # dependency: landing_zone -> landing_zone_vsi
  login_subnets    = length(var.login_subnets) > 0 ? var.login_subnets : module.landing_zone.login_subnets
  compute_subnets  = length(var.compute_subnets) > 0 ? var.compute_subnets : module.landing_zone.compute_subnets
  storage_subnets  = length(var.storage_subnets) > 0 ? var.storage_subnets : module.landing_zone.storage_subnets
  protocol_subnets = length(var.protocol_subnets) > 0 ? var.protocol_subnets : module.landing_zone.protocol_subnets

  #boot_volume_encryption_key = var.key_management != null ? one(module.landing_zone.boot_volume_encryption_key)["crn"] : null
  #skip_iam_authorization_policy = true
  #resource_group_id = data.ibm_resource_group.itself.id
  # vpc_id            = var.vpc == null ? module.landing_zone.vpc_id[0] : data.ibm_is_vpc.itself[0].id
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
  total_shares           = local.storage_instance_count > 0 ? [] : concat(local.default_share, var.file_shares)
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
  resource_group_id = module.landing_zone.resource_group_id == [] ? data.ibm_resource_group.resource_group[0].id : one(values(one(module.landing_zone.resource_group_id)))
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
  dns_custom_resolver_id = module.dns.dns_custom_resolver_id
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
  static_compute_instances = var.enable_bootstrap ? [] : var.static_compute_instances
  login_instances = var.enable_bootstrap ? [] : var.login_instances
  management_instances = var.enable_bootstrap ? [] : var.management_instances
  storage_instances = var.enable_bootstrap ? [] : var.storage_instances
  protocol_instances = var.enable_bootstrap ? [] : var.protocol_instances

  compute_instances_data  = var.enable_bootstrap ? [] : flatten([module.landing_zone_vsi.management_vsi_data, module.landing_zone_vsi.compute_vsi_data])
  storage_instances_data  = var.enable_bootstrap ? [] : flatten([module.landing_zone_vsi.storage_vsi_data, module.landing_zone_vsi.protocol_vsi_data])
  protocol_instances_data = var.enable_bootstrap ? [] : flatten([module.landing_zone_vsi.protocol_vsi_data])
  bootstrap_instances_data  = var.enable_bootstrap ? flatten([module.bootstrap.bootstrap_vsi_data]) : []

  compute_dns_records = var.enable_bootstrap ? [] : [
    for instance in local.compute_instances_data :
    {
      name  = instance["name"]
      rdata = instance["ipv4_address"]
    }
  ]
  storage_dns_records = var.enable_bootstrap ? [] : [
    for instance in local.storage_instances_data :
    {
      name  = instance["name"]
      rdata = instance["ipv4_address"]
    }
  ]
  protocol_dns_records = var.enable_bootstrap ? [] : [
    for instance in local.protocol_instances_data :
    {
      name  = instance["name"]
      rdata = instance["ipv4_address"]
    }
  ]
}

# locals needed for inventory
locals {
  compute_hosts          = var.enable_bootstrap ? [] : local.compute_instances_data[*]["ipv4_address"]
  storage_hosts          = var.enable_bootstrap ? [] : local.storage_instances_data[*]["ipv4_address"]
  bootstrap_hosts        = var.enable_bootstrap ? local.bootstrap_instances_data[*]["ipv4_address"] : []
  compute_inventory_path = "compute.ini"
  storage_inventory_path = "storage.ini"
}

# locals needed for playbook
locals {
  bastion_fip              = module.bastion.bastion_fip
  compute_private_key_path = "compute_id_rsa" #checkov:skip=CKV_SECRET_6
  storage_private_key_path = "storage_id_rsa" #checkov:skip=CKV_SECRET_6
  compute_playbook_path    = "compute_ssh.yaml"
  storage_playbook_path    = "storage_ssh.yaml"
}
