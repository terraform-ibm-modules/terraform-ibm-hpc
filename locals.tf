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

data "external" "get_hostname" {
  program = ["sh", "-c", "echo '{\"name\": \"'$(hostname)'\", \"ipv4_address\": \"'$(hostname -I | awk '{print $1}')'\"}'"]
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
  deployer_instances = [
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
  playbooks_root_path      = var.enable_bastion ? "${path.root}/../../modules/ansible-roles" : "${path.root}/modules/ansible-roles"
}

# file Share OutPut
locals {
  fileshare_name_mount_path_map =  var.enable_deployer ? {} : module.file_storage[0].name_mount_path_map
}

# details needed for json file
locals {
  json_inventory_path   = var.enable_bastion ?  "${path.root}/../../modules/ansible-roles/all.json" : "${path.root}/modules/ansible-roles/all.json"
  management_nodes      = var.enable_deployer ? [] : (flatten([module.landing_zone_vsi[0].management_vsi_data]))[*]["name"]
  compute_nodes         = var.enable_deployer ? [] : (flatten([module.landing_zone_vsi[0].compute_vsi_data]))[*]["name"]
  compute_nodes_list    = var.enable_deployer ? [] : (length(local.compute_nodes) > 0 ? [format("%s-[001:%s]", join("-", slice(split("-", local.compute_nodes[0]), 0, length(split("-", local.compute_nodes[0])) - 1)), split("-", local.compute_nodes[length(local.compute_nodes) - 1])[length(split("-", local.compute_nodes[length(local.compute_nodes) - 1])) - 1])] : local.compute_nodes) #(length(local.compute_nodes) >= 10 ? [format("%s-00[%d:%d]", regex("^(.*?)-\\d+$", local.compute_nodes[0])[0], 1, length(local.compute_nodes))] : local.compute_nodes)
  client_nodes          = var.enable_deployer ? [] : (flatten([module.landing_zone_vsi[0].client_vsi_data]))[*]["name"]
  gui_hosts             = var.enable_deployer ? [] : [local.management_nodes[0]] # Without Pac HA
  db_hosts              = var.enable_deployer ? [] : [local.management_nodes[0]] # Without Pac HA
  ha_shared_dir         = "/mnt/lsf/shared"
  nfs_install_dir       = "none"
  Enable_Monitoring     = false
  lsf_deployer_hostname = var.deployer_hostname #data.external.get_hostname.result.name  #var.enable_bastion ? "" : flatten(module.deployer.deployer_vsi_data[*].list)[0].name
  vcpus                 = var.enable_deployer ? 0 : tonumber(data.ibm_is_instance_profile.dynmaic_worker_profile.vcpu_count[0].value)
  ncores                = var.enable_deployer ? 0 : tonumber(local.vcpus / 2)
  ncpus                 = var.enable_deployer ? 0 : tonumber(var.enable_hyperthreading ? local.vcpus : local.ncores)
  memInMB               = var.enable_deployer ? 0 : tonumber(data.ibm_is_instance_profile.dynmaic_worker_profile.memory[0].value) * 1024
  rc_maxNum             = var.enable_deployer ? 0 : tonumber(var.dynamic_compute_instances[0].count)
  rc_profile            = var.enable_deployer ? "" : var.dynamic_compute_instances[0].profile
  imageID               = var.enable_deployer ? ""  : data.ibm_is_image.dynamic_compute.id
  compute_subnets_cidr  = var.compute_subnets_cidr
  dynamic_compute_instances = var.dynamic_compute_instances
  compute_subnet_crn    = data.ibm_is_subnet.compute_subnet_crn.crn
  compute_ssh_keys_ids  = [for name in local.compute_ssh_keys : data.ibm_is_ssh_key.compute_ssh_keys[name].id]
}

locals {
  schematics_inputs_path    = "/tmp/.schematics/solution_terraform.auto.tfvars.json"
  remote_inputs_path        = format("%s/terraform.tfvars.json", "/tmp")
  deployer_path             = "/opt/ibm"
  remote_terraform_path     = format("%s/terraform-ibm-hpc", local.deployer_path)
  remote_ansible_path       = format("%s/terraform-ibm-hpc", local.deployer_path)
  da_hpc_repo_url           = "https://github.com/terraform-ibm-modules/terraform-ibm-hpc.git"
  da_hpc_repo_tag           = "latest_code_anand" ###### change it to main in future
  zones                     = jsonencode(var.zones)
  list_compute_ssh_keys     = jsonencode(local.compute_ssh_keys)
  list_storage_ssh_keys     = jsonencode(local.storage_ssh_keys)
  list_storage_instances    = jsonencode(var.storage_instances)
  list_management_instances = jsonencode(var.management_instances)
  list_protocol_instances   = jsonencode(var.protocol_instances)
  list_compute_instances    = jsonencode(var.static_compute_instances)
  list_client_instances     = jsonencode(var.client_instances)
  allowed_cidr              = jsonencode(var.allowed_cidr)
  list_storage_subnets      = jsonencode(length(local.storage_subnet) == 0 ? null : local.storage_subnet)
  list_protocol_subnets     = jsonencode(length(local.protocol_subnet) == 0 ? null : local.protocol_subnet)
  list_compute_subnets      = jsonencode(length(local.compute_subnet) == 0 ? null : local.compute_subnet)
  list_client_subnets       = jsonencode(length(local.client_subnet) == 0 ? null : local.client_subnet)
  list_bastion_subnets      = jsonencode(length(local.bastion_subnet) == 0 ? null : local.bastion_subnet)
  dns_domain_names          = jsonencode(var.dns_domain_names)
  compute_public_key_content  = local.compute_public_key_contents != null ? jsonencode(base64encode(local.compute_public_key_contents)) : ""
  compute_private_key_content = local.compute_private_key_contents != null ? jsonencode(base64encode(local.compute_private_key_contents)) : ""
}