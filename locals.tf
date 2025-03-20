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
  gklm_instance_key_pair  = distinct(concat(coalesce(var.gklm_instance_key_pair, []), coalesce(var.ssh_keys, [])))
  ldap_instance_key_pair    = distinct(concat(coalesce(var.ldap_instance_key_pair, []), coalesce(var.ssh_keys, [])))
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
  cos_data                   = var.enable_bastion ? [] : module.landing_zone.cos_buckets_data
  # Future use
  # skip_iam_authorization_policy = true
}


# locals needed for landing_zone_vsi
locals {
  # dependency: landing_zone -> deployer -> landing_zone_vsi
  bastion_security_group_id   = module.deployer.bastion_security_group_id
  bastion_public_key_content  = module.deployer.bastion_public_key_content
  bastion_private_key_content = module.deployer.bastion_private_key_content

  deployer_hostname = var.enable_bastion ? flatten(module.deployer.deployer_vsi_data[*].list)[0].name : ""
  deployer_ip = module.deployer.deployer_ip

  compute_public_key_contents  = module.deployer.compute_public_key_content
  compute_private_key_contents = module.deployer.compute_private_key_content

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

  existing_storage_subnets = [
    for subnet in data.ibm_is_subnet.existing_storage_subnets :
    {
      cidr = subnet.ipv4_cidr_block
      id   = subnet.id
      name = subnet.name
      zone = subnet.zone
    }
  ]

  existing_protocol_subnets = [
    for subnet in data.ibm_is_subnet.existing_protocol_subnets :
    {
      cidr = subnet.ipv4_cidr_block
      id   = subnet.id
      name = subnet.name
      zone = subnet.zone
    }
  ]

  existing_client_subnets = [
    for subnet in data.ibm_is_subnet.existing_client_subnets :
    {
      cidr = subnet.ipv4_cidr_block
      id   = subnet.id
      name = subnet.name
      zone = subnet.zone
    }
  ]

    existing_bastion_subnets = [
    for subnet in data.ibm_is_subnet.existing_bastion_subnets :
    {
      cidr = subnet.ipv4_cidr_block
      id   = subnet.id
      name = subnet.name
      zone = subnet.zone
    }
  ]

  # dependency: landing_zone -> landing_zone_vsi
  client_subnets   = var.vpc != null && var.client_subnets != null ? local.existing_client_subnets : module.landing_zone.client_subnets
  compute_subnets  = var.vpc != null && var.compute_subnets != null ? local.existing_compute_subnets : module.landing_zone.compute_subnets
  storage_subnets  = var.vpc != null && var.storage_subnets != null ? local.existing_storage_subnets : module.landing_zone.storage_subnets
  protocol_subnets = var.vpc != null && var.protocol_subnets != null ? local.existing_protocol_subnets : module.landing_zone.protocol_subnets

  storage_subnet  = [for subnet in local.storage_subnets : subnet.name]
  protocol_subnet = [for subnet in local.protocol_subnets : subnet.name]
  compute_subnet  = [for subnet in local.compute_subnets : subnet.name]
  client_subnet   = [for subnet in local.client_subnets : subnet.name]
  bastion_subnet  = [for subnet in local.bastion_subnets : subnet.name]

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
  default_share = local.management_instance_count > 0 ? [
    {
      mount_path = "/mnt/lsf"
      size       = 100
      iops       = 1000
    }
  ] : []

  management_instance_count = sum(var.management_instances[*]["count"])
  storage_instance_count = sum(var.storage_instances[*]["count"])
  client_instance_count         = sum(var.client_instances[*]["count"])
  protocol_instance_count       = sum(var.protocol_instances[*]["count"])
  static_compute_instance_count = sum(var.static_compute_instances[*]["count"])
  afm_instance_count            = sum(var.afm_instances[*]["count"])

  total_shares           = local.storage_instance_count > 0 ? var.file_shares : concat(local.default_share, var.file_shares)
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
  #subnets_crn       = var.vpc == null ? module.landing_zone.subnets_crn : ###
  existing_compute_subnet_crns  = [for subnet in data.ibm_is_subnet.existing_compute_subnets : subnet.crn]
  existing_storage_subnet_crns  = [for subnet in data.ibm_is_subnet.existing_storage_subnets : subnet.crn]
  existing_protocol_subnet_crns = [for subnet in data.ibm_is_subnet.existing_protocol_subnets : subnet.crn]
  existing_client_subnet_crns   = [for subnet in data.ibm_is_subnet.existing_client_subnets : subnet.crn]
  existing_bastion_subnet_crns  = [for subnet in data.ibm_is_subnet.existing_bastion_subnets : subnet.crn]
  subnets_crn = concat(local.existing_compute_subnet_crns, local.existing_storage_subnet_crns, local.existing_protocol_subnet_crns, local.existing_client_subnet_crns, local.existing_bastion_subnet_crns)
  # subnets_crn        = var.vpc == null && var.compute_subnets == null ? module.landing_zone.subnets_crn : concat(local.existing_subnet_crns, module.landing_zone.subnets_crn)
  #subnets           = flatten([local.compute_subnets, local.storage_subnets, local.protocol_subnets])
  #subnets_crns      = data.ibm_is_subnet.itself[*].crn
  # subnets_crn = module.landing_zone.subnets_crn
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
  client_dns_zone_id = one(flatten([
    for dns_zone in local.dns_zone_map_list : values(dns_zone) if one(keys(dns_zone)) == var.dns_domain_names["client"]
  ]))
  gklm_dns_zone_id = one(flatten([
    for dns_zone in local.dns_zone_map_list : values(dns_zone) if one(keys(dns_zone)) == var.dns_domain_names["gklm"]
  ]))

  # dependency: landing_zone_vsi -> dns-records
  compute_instances   = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].management_vsi_data, module.landing_zone_vsi[0].compute_vsi_data, module.landing_zone_vsi[0].compute_management_vsi_data])
  storage_instances   = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].storage_vsi_data, module.landing_zone_vsi[0].protocol_vsi_data, module.landing_zone_vsi[0].afm_vsi_data, module.landing_zone_vsi[0].storage_cluster_tie_breaker_vsi_data, module.landing_zone_vsi[0].storage_cluster_management_vsi])
  protocol_instances  = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].protocol_vsi_data])
  gklm_instances      = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].gklm_vsi_data])
  client_instances    = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].client_vsi_data])
  afm_instances       = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].afm_vsi_data])
  # ldap_instances      = var.enable_deployer ? [] : flatten(module.landing_zone_vsi[0].ldap_vsi_data)
  tie_brkr_instances  = var.enable_deployer ? [] : flatten(module.landing_zone_vsi[0].storage_cluster_tie_breaker_vsi_data)
  # comp_mgmt_instances = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].compute_management_vsi_data])
  strg_mgmt_instances = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].storage_cluster_management_vsi])
  deployer_instances  = [
    {
      name         = var.deployer_hostname
      ipv4_address = var.deployer_ip
    }
  ]

  compute_dns_records = [
    for instance in concat(local.compute_instances, local.deployer_instances):
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
  client_dns_records = [
    for instance in local.client_instances :
    {
      name  = instance["name"]
      rdata = instance["ipv4_address"]
    }
  ]
  gklm_dns_records = [
    for instance in local.gklm_instances :
    {
      name  = instance["name"]
      rdata = instance["ipv4_address"]
    }
  ]
}

# locals needed for inventory
locals {
  compute_hosts          = try([for name in local.compute_instances[*]["name"] : "${name}.${var.dns_domain_names["compute"]}"], []) #concat(["${data.external.get_hostname.result["name"]}.${var.dns_domain_names["compute"]}"], try([for name in local.compute_instances[*]["name"] : "${name}.${var.dns_domain_names["compute"]}"], []))
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
  fileshare_name_mount_path_map =  var.enable_deployer ? {} : (var.scheduler != null ? module.file_storage[0].name_mount_path_map : {})
}

locals {
  # gpfs_base_rpm_path  = fileset(var.spectrumscale_rpms_path, "gpfs.base-*")
  # scale_org_version   = regex("gpfs.base-(.*).x86_64.rpm", tolist(local.gpfs_base_rpm_path)[0])[0]
  scale_version       = "5221" #replace(local.scale_org_version, "-", ".")
  
  compute_vsi_profile    = var.static_compute_instances[*]["profile"]
  storage_vsi_profile    = var.storage_instances[*]["profile"]
  management_vsi_profile = var.management_instances[*]["profile"]
  afm_vsi_profile        = var.afm_instances[*]["profile"]
  protocol_vsi_profile   = var.protocol_instances[*]["profile"]
  afm_server_type        = strcontains(local.afm_vsi_profile[0], "metal")
  ces_server_type        = strcontains(local.protocol_vsi_profile[0], "metal")

  scale_ces_enabled            = local.protocol_instance_count > 0 ? true : false
  # is_colocate_protocol_subset  = local.scale_ces_enabled && var.colocate_protocol_cluster_instances ? local.protocol_instance_count < local.total_storage_cluster_instances ? true : false : false
  enable_sec_interface_compute = local.scale_ces_enabled == false && data.ibm_is_instance_profile.compute_profile.bandwidth[0].value >= 64000 ? true : false
  enable_sec_interface_storage = local.scale_ces_enabled == false && var.storage_type != "persistent" && data.ibm_is_instance_profile.storage_profile.bandwidth[0].value >= 64000 ? true : false
  enable_mrot_conf             = local.enable_sec_interface_compute && local.enable_sec_interface_storage ? true : false

  compute_instance_private_ips = flatten(local.compute_instances[*]["ipv4_address"])
  compute_instance_ids         = flatten(local.compute_instances[*]["id"])
  compute_instance_names       = flatten(local.compute_instances[*]["name"])

  storage_instance_private_ips = flatten(local.storage_instances[*]["ipv4_address"])
  storage_instance_ids         = flatten(local.storage_instances[*]["id"])
  storage_instance_names       = flatten(local.storage_instances[*]["name"])

  storage_mgmt_instance_private_ips = flatten(local.strg_mgmt_instances[*]["ipv4_address"])
  storage_mgmtt_instance_ids        = flatten(local.strg_mgmt_instances[*]["id"])
  storage_mgmt_instance_names       = flatten(local.strg_mgmt_instances[*]["name"])

  strg_tie_breaker_private_ips    = flatten(local.tie_brkr_instances[*]["ipv4_address"])
  strg_tie_breaker_instance_ids   = flatten(local.tie_brkr_instances[*]["id"])
  strg_tie_breaker_instance_names = flatten(local.tie_brkr_instances[*]["name"])

  secondary_compute_instance_private_ips = flatten(local.compute_instances[*]["secondary_ipv4_address"])
  secondary_storage_instance_private_ips = flatten(local.storage_instances[*]["secondary_ipv4_address"])

  afm_instance_private_ips = flatten(local.afm_instances[*]["ipv4_address"])
  afm_instance_ids         = flatten(local.afm_instances[*]["id"])
  afm_instance_names       = flatten(local.afm_instances[*]["name"])

  protocol_instance_private_ips = flatten(local.protocol_instances[*]["ipv4_address"])
  protocol_instance_ids         = flatten(local.protocol_instances[*]["id"])
  protocol_instance_names       = flatten(local.protocol_instances[*]["name"])

  client_instance_private_ips = flatten(local.client_instances[*]["ipv4_address"])
  client_instance_ids         = flatten(local.client_instances[*]["id"])
  client_instance_names       = flatten(local.client_instances[*]["name"])

  gklm_instance_private_ips = flatten(local.gklm_instances[*]["ipv4_address"])
  gklm_instance_ids         = flatten(local.gklm_instances[*]["id"])
  gklm_instance_names       = flatten(local.gklm_instances[*]["name"])
}

# details needed for json file
locals {
  json_inventory_path   = var.enable_bastion ? "${path.root}/../../modules/ansible-roles/" : "${path.root}/modules/ansible-roles/"
  management_nodes      = var.scheduler == "LSF" ? var.enable_deployer ? [] : (flatten([module.landing_zone_vsi[0].management_vsi_data]))[*]["name"] : []
  compute_nodes         = var.scheduler == "LSF" ? var.enable_deployer ? [] : (flatten([module.landing_zone_vsi[0].compute_vsi_data]))[*]["name"] : []
  client_nodes          = var.scheduler == "LSF" ? var.enable_deployer ? [] : (flatten([module.landing_zone_vsi[0].client_vsi_data]))[*]["name"] : []
  gui_hosts             = var.scheduler == "LSF" ? var.enable_deployer ? [] : [local.management_nodes[0]] : [] # Without Pac HA
  db_hosts              = var.scheduler == "LSF" ? var.enable_deployer ? [] : [local.management_nodes[0]] : [] # Without Pac HA
  ha_shared_dir         = var.scheduler == "LSF" ? "/mnt/lsf/shared" : ""
  nfs_install_dir       = var.scheduler == "LSF" ? "none" : "none"
  Enable_Monitoring     = var.scheduler == "LSF" ? false : false
  lsf_deployer_hostname = var.scheduler == "LSF" ? var.deployer_hostname : ""
  my_cluster_name       = var.scheduler == "LSF" ? var.prefix : ""
}

locals {
  schematics_inputs_path    = "/tmp/.schematics/solution_terraform.auto.tfvars.json"
  remote_inputs_path        = format("%s/terraform.tfvars.json", "/tmp")
  deployer_path             = "/opt/ibm"
  remote_terraform_path     = format("%s/terraform-ibm-hpc", local.deployer_path)
  remote_ansible_path       = format("%s/terraform-ibm-hpc", local.deployer_path)
  da_hpc_repo_url           = "https://github.com/terraform-ibm-modules/terraform-ibm-hpc.git"
  da_hpc_repo_tag           = "jay_da_scale_deployer" ###### change it to main in future
  zones                     = jsonencode(var.zones)
  list_compute_ssh_keys     = jsonencode(local.compute_ssh_keys)
  list_storage_ssh_keys     = jsonencode(local.storage_ssh_keys)
  list_storage_instances    = jsonencode(var.storage_instances)
  list_management_instances = jsonencode(var.management_instances)
  list_protocol_instances   = jsonencode(var.protocol_instances)
  list_compute_instances    = jsonencode(var.static_compute_instances)
  list_client_instances     = jsonencode(var.client_instances)
  list_client_ssh_keys      = jsonencode(var.client_ssh_keys)
  allowed_cidr              = jsonencode(var.allowed_cidr)
  list_storage_subnets      = jsonencode(length(local.storage_subnet) == 0 ? null : local.storage_subnet)
  list_protocol_subnets     = jsonencode(length(local.protocol_subnet) == 0 ? null : local.protocol_subnet)
  list_compute_subnets      = jsonencode(length(local.compute_subnet) == 0 ? null : local.compute_subnet)
  list_client_subnets       = jsonencode(length(local.client_subnet) == 0 ? null : local.client_subnet)
  list_bastion_subnets      = jsonencode(length(local.bastion_subnet) == 0 ? null : local.bastion_subnet)
  dns_domain_names          = jsonencode(var.dns_domain_names)
  compute_public_key_content  = local.compute_public_key_contents != null ? jsonencode(base64encode(local.compute_public_key_contents)) : ""
  compute_private_key_content = local.compute_private_key_contents != null ? jsonencode(base64encode(local.compute_private_key_contents)) : ""
  list_ldap_instances       = jsonencode(var.ldap_instances)
  ldap_server               = jsonencode(var.ldap_server)
  list_ldap_ssh_keys        = jsonencode(local.ldap_instance_key_pair)
  list_afm_instances        = jsonencode(var.afm_instances)
  list_gklm_ssh_keys        = jsonencode(local.gklm_instance_key_pair)
  list_gklm_instances       = jsonencode(var.gklm_instances)
  scale_encryption_type     = jsonencode(var.scale_encryption_type)
}

# locals {
#   ldap_private_ips = local.ldap_instances[*]["ipv4_address"]
#   ldap_hostnames   = local.ldap_instances[*]["name"]
# }