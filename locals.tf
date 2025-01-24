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
  vpc_id                     = var.vpc == null ? one(module.landing_zone.vpc_id) : var.vpc_id
  vpc                        = var.vpc == null ? one(module.landing_zone.vpc_name) : var.vpc
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
  
  # Existing subnets details
  existing_compute_subnets = [
    for subnet in data.ibm_is_subnet.existing_compute_subnets :
    {
      cidr = subnet.ipv4_cidr_block
      id   = subnet.id
      name = subnet.name
      zone = subnet.zone
    }
  ]
  # existing_storage_subnets_subnets = [
  #   for subnet in data.ibm_is_subnet.existing_storage_subnets :
  #   {
  #     cidr = subnet.ipv4_cidr_block
  #     id   = subnet.id
  #     name = subnet.name
  #     zone = subnet.zone
  #   }
  # ]

  # dependency: landing_zone -> landing_zone_vsi
  client_subnets   = module.landing_zone.client_subnets
  compute_subnets  = var.vpc != null && var.compute_subnets != null ? local.existing_compute_subnets : module.landing_zone.compute_subnets
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
  compute_subnet_id         = var.vpc == null && var.compute_subnets == null ? local.compute_subnets[0].id : [for subnet in data.ibm_is_subnet.existing_compute_subnets : subnet.id][0]
  compute_security_group_id = var.enable_deployer ? [] : module.landing_zone_vsi[0].compute_sg_id
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
  resource_group = var.resource_group == null ? "workload-rg" : var.resource_group
  resource_group_ids = {
    # management_rg = var.resource_group == null ? module.landing_zone.resource_group_id[0]["management-rg"] : one(values(one(module.landing_zone.resource_group_id)))
    service_rg  = var.resource_group == null ? module.landing_zone.resource_group_id[0]["service-rg"] : data.ibm_resource_group.resource_group[0].id
    workload_rg = var.resource_group == null ? module.landing_zone.resource_group_id[0]["workload-rg"] : data.ibm_resource_group.resource_group[0].id
  }
  # resource_group_id = one(values(one(module.landing_zone.resource_group_id)))
  vpc_crn           = var.vpc == null ? one(module.landing_zone.vpc_crn) : one(data.ibm_is_vpc.itself[*].crn)
  # TODO: Fix existing subnet logic
  existing_subnet_crns = [for subnet in data.ibm_is_subnet.existing_compute_subnets : subnet.crn]
  subnets_crn        = var.vpc == null && var.compute_subnets == null ? module.landing_zone.subnets_crn : local.existing_subnet_crns
  #subnets           = flatten([local.compute_subnets, local.storage_subnets, local.protocol_subnets])
  #subnets_crns      = data.ibm_is_subnet.itself[*].crn
  #subnets_crn = module.landing_zone.subnets_crn
  #boot_volume_encryption_key    = var.key_management != null ? one(module.landing_zone.boot_volume_encryption_key)["crn"] : null

  # dependency: landing_zone_vsi -> file-share
}

# locals needed for dns-records
locals {
  # dependency: dns -> dns-records
  dns_instance_id = var.enable_deployer ? "" : module.dns[0].dns_instance_id
  dns_custom_resolver_id = var.enable_deployer ? "" : module.dns[0].dns_custom_resolver_id
  dns_zone_map_list = var.enable_deployer ? [] : module.dns[0].dns_zone_maps
  compute_dns_zone_id = one(flatten([
    for dns_zone in local.dns_zone_map_list : values(dns_zone) if one(keys(dns_zone)) == var.dns_domain_names["compute"]
  ]))
  storage_dns_zone_id = one(flatten([
    for dns_zone in local.dns_zone_map_list : values(dns_zone) if one(keys(dns_zone)) == var.dns_domain_names["storage"]
  ]))
  protocol_dns_zone_id = one(flatten([
    for dns_zone in local.dns_zone_map_list : values(dns_zone) if one(keys(dns_zone)) == var.dns_domain_names["protocol"]
  ]))

  # dependency: landing_zone_vsi -> dns-records
  compute_instances  = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].management_vsi_data, module.landing_zone_vsi[0].compute_vsi_data])
  storage_instances  = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].storage_vsi_data, module.landing_zone_vsi[0].protocol_vsi_data])
  protocol_instances = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].protocol_vsi_data])

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
  compute_hosts          = try([for name in local.compute_instances[*]["name"] : "${name}.${var.dns_domain_names["compute"]}"], [])
  storage_hosts          = try([for name in local.storage_instances[*]["name"] : "${name}.${var.dns_domain_names["storage"]}"], [])
  compute_inventory_path = var.enable_bastion ? "${path.root}/../../modules/ansible-roles/compute.ini" : "${path.root}/modules/ansible-roles/compute.ini"
  storage_inventory_path = var.enable_bastion ? "${path.root}/../../modules/ansible-roles/storage.ini" : "${path.root}/modules/ansible-roles/storage.ini"
}

# locals needed for playbook
locals {
  bastion_fip              = module.deployer.bastion_fip
  compute_private_key_path = var.enable_bastion ? "${path.root}/../../modules/ansible-roles/compute_id_rsa" : "${path.root}/modules/ansible-roles/compute_id_rsa" #checkov:skip=CKV_SECRET_6
  storage_private_key_path = var.enable_bastion ? "${path.root}/../../modules/ansible-roles/storage_id_rsa" : "${path.root}/modules/ansible-roles/storage_id_rsa" #checkov:skip=CKV_SECRET_6
  compute_playbook_path    = var.enable_bastion ? "${path.root}/../../modules/ansible-roles/compute_ssh.yaml" : "${path.root}/modules/ansible-roles/compute_ssh.yaml" 
  storage_playbook_path    = var.enable_bastion ? "${path.root}/../../modules/ansible-roles/storage_ssh.yaml" : "${path.root}/modules/ansible-roles/storage_ssh.yaml"
}

# file Share OutPut
locals {
  fileshare_name_mount_path_map =  var.enable_deployer ? {} : module.file_storage[0].name_mount_path_map
}
