# locals needed for landing_zone
locals {
  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))

  # SSH key calculations
  # Combining the common ssh keys with host specific ssh keys
  gklm_instance_key_pair = distinct(concat(coalesce(var.gklm_instance_key_pair, []), coalesce(var.ssh_keys, [])))
  ldap_instance_key_pair = distinct(concat(coalesce(var.ldap_instance_key_pair, []), coalesce(var.ssh_keys, [])))
  ssh_keys               = distinct(coalesce(var.ssh_keys, []))
  key_management         = var.key_management == "null" ? null : var.key_management
  ldap_server            = var.ldap_server == null ? "null" : var.ldap_server
  ldap_admin_password    = var.ldap_admin_password == null ? "" : var.ldap_admin_password
  ldap_server_cert       = var.ldap_server_cert == null ? "null" : var.ldap_server_cert
}

# locals needed for deployer
locals {
  # dependency: landing_zone -> deployer
  vpc_id                     = var.vpc_name == null ? one(module.landing_zone.vpc_id) : data.ibm_is_vpc.existing_vpc[0].id
  vpc_name                   = var.vpc_name == null ? one(module.landing_zone.vpc_name) : var.vpc_name
  kms_encryption_enabled     = local.key_management != null ? true : false
  boot_volume_encryption_key = local.key_management != null && var.enable_deployer ? one(module.landing_zone.boot_volume_encryption_key)["crn"] : null
  existing_kms_instance_guid = local.key_management != null ? module.landing_zone.key_management_guid : null
  cos_data                   = module.landing_zone.cos_buckets_data
  # Future use
  # When we implement the existing bastion concept we need the changes to implemented like below. Which is already there on our LSF DA
  # skip_iam_authorization_policy = true
  # skip_iam_authorization_policy = var.bastion_instance_name != null ? false : local.skip_iam_authorization_policy
  # Cluster node details:
  compute_instances   = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].management_vsi_data, module.landing_zone_vsi[0].compute_vsi_data])
  comp_mgmt_instances = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].compute_management_vsi_data])
  storage_instances   = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].storage_vsi_data])
  storage_servers     = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].storage_bms_data])
  protocol_instances  = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].protocol_vsi_data])
  gklm_instances      = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].gklm_vsi_data])
  client_instances    = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].client_vsi_data])
  afm_instances       = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].afm_vsi_data])
  ldap_instances      = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].ldap_vsi_data])
  tie_brkr_instances  = var.enable_deployer ? [] : flatten(module.landing_zone_vsi[0].storage_cluster_tie_breaker_vsi_data)
  strg_mgmt_instances = var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].storage_cluster_management_vsi])
  login_instance      = var.enable_deployer ? [] : flatten(module.landing_zone_vsi[0].login_vsi_data)

  management_instance_count     = sum(var.management_instances[*]["count"])
  storage_instance_count        = var.storage_type == "persistent" ? sum(var.storage_servers[*]["count"]) : sum(var.storage_instances[*]["count"])
  client_instance_count         = sum(var.client_instances[*]["count"])
  protocol_instance_count       = sum(var.protocol_instances[*]["count"])
  static_compute_instance_count = sum(var.static_compute_instances[*]["count"])
  # afm_instance_count            = sum(var.afm_instances[*]["count"])
}

# locals needed for landing_zone_vsi
locals {
  # dependency: landing_zone -> deployer -> landing_zone_vsi
  bastion_security_group_id   = module.deployer.bastion_security_group_id
  bastion_public_key_content  = module.deployer.bastion_public_key_content
  bastion_private_key_content = module.deployer.bastion_private_key_content

  deployer_hostname = var.enable_deployer ? flatten(module.deployer.deployer_vsi_data[*].list)[0].name : ""
  deployer_ip       = module.deployer.deployer_ip

  # Existing subnets details
  existing_cluster_subnets = [
    for subnet in data.ibm_is_subnet.existing_cluster_subnets :
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

  existing_login_subnets = [
    for subnet in data.ibm_is_subnet.existing_login_subnets :
    {
      cidr = subnet.ipv4_cidr_block
      id   = subnet.id
      name = subnet.name
      zone = subnet.zone
    }
  ]

  # dependency: landing_zone -> landing_zone_vsi
  client_subnets   = var.vpc_name != null && var.client_subnets != null ? local.existing_client_subnets : module.landing_zone.client_subnets
  cluster_subnets  = var.vpc_name != null && var.cluster_subnet_id != null ? local.existing_cluster_subnets : module.landing_zone.compute_subnets
  storage_subnets  = var.vpc_name != null && var.storage_subnets != null ? local.existing_storage_subnets : module.landing_zone.storage_subnets
  protocol_subnets = var.vpc_name != null && var.protocol_subnets != null ? local.existing_protocol_subnets : module.landing_zone.protocol_subnets
  login_subnets    = var.vpc_name != null && var.login_subnet_id != null ? local.existing_login_subnets : module.landing_zone.bastion_subnets

  storage_subnet     = [for subnet in local.storage_subnets : subnet.name]
  protocol_subnet    = [for subnet in local.protocol_subnets : subnet.name]
  protocol_subnet_id = local.protocol_instance_count > 0 ? [for subnet in local.protocol_subnets : subnet.id][0] : ""
  cluster_subnet     = [for subnet in local.cluster_subnets : subnet.id][0]
  client_subnet      = [for subnet in local.client_subnets : subnet.name]
  login_subnet       = [for subnet in local.login_subnets : subnet.id][0]

  #boot_volume_encryption_key = local.key_management != null ? one(module.landing_zone.boot_volume_encryption_key)["crn"] : null
  #skip_iam_authorization_policy = true
}

# locals needed for file-storage
locals {
  # dependency: landing_zone_vsi -> file-share
  compute_subnet_id         = (var.vpc_name == null && var.cluster_subnet_id == null ? local.cluster_subnets[0].id : (var.vpc_name != null && var.cluster_subnet_id != null ? [for subnet in data.ibm_is_subnet.existing_cluster_subnets : subnet.id][0] : (var.vpc_name != null && var.cluster_subnet_id == null ? local.cluster_subnets[0].id : "")))
  bastion_subnet_id         = (var.enable_deployer && var.vpc_name != null && var.login_subnet_id != null) ? local.existing_login_subnets[0].id : ""
  subnet_id                 = (var.enable_deployer && var.vpc_name != null && var.cluster_subnet_id != null) ? local.existing_cluster_subnets[0].id : ""
  compute_security_group_id = var.enable_deployer ? [] : module.landing_zone_vsi[0].compute_sg_id

  nfs_shares_map = {
    for share in var.custom_file_shares :
    share.mount_path => share.nfs_share
    if share.nfs_share != "" && share.nfs_share != null
  }

  fileset_size_map = try({ for details in var.custom_file_shares : details.mount_path => details.size }, {})

  # Original file share map from module
  original_map = var.enable_deployer ? {} : module.file_storage[0].name_mount_path_map

  # Extract keyword-to-target mapping from file share names
  keyword_to_target_map = var.enable_deployer ? {} : {
    for k, v in local.original_map :
    split("-", k)[length(split("-", k)) - 4] => v
  }

  # Build base map from custom_file_shares (excluding any with `nfs_share`)
  base_fileshare_map = var.enable_deployer ? {} : {
    for share in var.custom_file_shares :
    share.mount_path => lookup(local.keyword_to_target_map, regex("[^/]+$", share.mount_path), null)
    if(
      share.nfs_share == null &&
      contains(keys(local.keyword_to_target_map), regex("[^/]+$", share.mount_path))
    )
  }

  # Check if "lsf" is present in the keyword map (i.e., provisioned by Terraform)
  lsf_exists = contains(keys(local.keyword_to_target_map), "lsf")

  # Check if "lsf" is explicitly provided in custom_file_shares (any type)
  lsf_in_shares = length([
    for share in var.custom_file_shares :
    share if regex("[^/]+$", share.mount_path) == "lsf"
  ]) > 0

  # Final VPC fileshare map with /mnt/lsf auto-added only if it's not already in custom_file_shares AND was provisioned by Terraform
  fileshare_name_mount_path_map = var.enable_deployer ? {} : merge(
    local.base_fileshare_map,
    (
      local.lsf_exists && !local.lsf_in_shares ?
      { "/mnt/lsf" = local.keyword_to_target_map["lsf"] } :
      {}
    )
  )

  valid_lsf_shares = [
    for share in var.custom_file_shares :
    {
      mount_path = "/mnt/lsf"
      nfs_share  = share.nfs_share
    }
    if share.mount_path == "/mnt/lsf" && share.nfs_share != "" && share.nfs_share != null
  ]

  valid_default_vpc_share = [
    for share in var.custom_file_shares :
    {
      mount_path = "/mnt/lsf"
      size       = share.size
      iops       = share.size
    }
    if share.mount_path == "/mnt/lsf" && share.size != null && share.iops != null
  ]
  default_share = local.management_instance_count > 0 && length(local.valid_lsf_shares) == 0 && length(local.valid_default_vpc_share) == 0 ? [
    {
      mount_path = "/mnt/lsf"
      size       = 100
      iops       = 1000
    }
  ] : []

  vpc_file_share = [
    for share in var.custom_file_shares :
    {
      mount_path = share.mount_path
      size       = share.size
      iops       = share.iops
    }
    if share.size != null && share.iops != null && share.mount_path != "/mnt/lsf"
  ]

  total_shares = concat(length(local.valid_default_vpc_share) == 1 ? local.valid_default_vpc_share : local.default_share, local.vpc_file_share)
  file_shares = [
    for count in range(length(local.total_shares)) :
    {
      name = format("%s-%s", var.cluster_prefix, element(split("/", local.total_shares[count]["mount_path"]), length(split("/", local.total_shares[count]["mount_path"])) - 1))
      size = local.total_shares[count]["size"]
      iops = local.total_shares[count]["iops"]
    }
  ]
}

# locals needed for DNS
locals {
  # dependency: landing_zone -> DNS
  # resource_group = var.existing_resource_group == null ? "workload-rg" : var.existing_resource_group
  resource_group_ids = {
    # management_rg = var.existing_resource_group == null ? module.landing_zone.resource_group_id[0]["management-rg"] : one(values(one(module.landing_zone.resource_group_id)))
    service_rg  = var.enable_deployer ? (var.existing_resource_group == "null" ? module.landing_zone.resource_group_id[0]["${var.cluster_prefix}-service-rg"] : one(values(one(module.landing_zone.resource_group_id)))) : ""
    workload_rg = var.enable_deployer ? (var.existing_resource_group == "null" ? module.landing_zone.resource_group_id[0]["${var.cluster_prefix}-workload-rg"] : one(values(one(module.landing_zone.resource_group_id)))) : ""
  }
  # resource_group_id = one(values(one(module.landing_zone.resource_group_id)))
  vpc_crn = var.vpc_name == null ? one(module.landing_zone.vpc_crn) : one(data.ibm_is_vpc.existing_vpc[*].crn)
  # TODO: Fix existing subnet logic
  #subnets_crn       = var.vpc_name == null ? module.landing_zone.subnets_crn : ###
  existing_compute_subnet_crns  = [for subnet in data.ibm_is_subnet.existing_cluster_subnets : subnet.crn]
  existing_storage_subnet_crns  = [for subnet in data.ibm_is_subnet.existing_storage_subnets : subnet.crn]
  existing_protocol_subnet_crns = [for subnet in data.ibm_is_subnet.existing_protocol_subnets : subnet.crn]
  existing_client_subnet_crns   = [for subnet in data.ibm_is_subnet.existing_client_subnets : subnet.crn]
  existing_bastion_subnet_crns  = [for subnet in data.ibm_is_subnet.existing_login_subnets : subnet.crn]
  subnets_crn                   = concat(local.existing_compute_subnet_crns, local.existing_storage_subnet_crns, local.existing_protocol_subnet_crns, local.existing_client_subnet_crns, local.existing_bastion_subnet_crns)
  # subnets_crn                 = var.vpc_name == null && var.cluster_subnet_id == null ? module.landing_zone.subnets_crn : concat(local.existing_subnet_crns, module.landing_zone.subnets_crn)
  # subnets                     = flatten([local.cluster_subnets, local.storage_subnets, local.protocol_subnets])
  # subnets_crns                = data.ibm_is_subnet.itself[*].crn
  # subnets_crn                 = module.landing_zone.subnets_crn
  # boot_volume_encryption_key  = local.key_management != null ? one(module.landing_zone.boot_volume_encryption_key)["crn"] : null

  # dependency: landing_zone_vsi -> file-share
}

# locals needed for dns-records
locals {
  # dependency: dns -> dns-records
  dns_instance_id = var.enable_deployer ? "" : module.dns[0].dns_instance_id
  # dns_custom_resolver_id = var.enable_deployer ? "" : module.dns[0].dns_custom_resolver_id
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
  deployer_instances = [
    {
      name         = var.deployer_hostname
      ipv4_address = var.deployer_ip
    }
  ]

  compute_dns_records = [
    for instance in concat(local.compute_instances, local.comp_mgmt_instances, local.deployer_instances, local.login_instance) :
    {
      name  = instance["name"]
      rdata = instance["ipv4_address"]
    }
  ]
  storage_dns_records = [
    for instance in concat(local.storage_instances, local.protocol_instances, local.afm_instances, local.tie_brkr_instances, local.strg_mgmt_instances, local.storage_servers) :
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
  compute_hosts = try([for name in local.compute_instances[*]["name"] : "${name}.${var.dns_domain_names["compute"]}"], [])
  # storage_hosts                = try([for name in local.storage_instances[*]["name"] : "${name}.${var.dns_domain_names["storage"]}"], [])
  ldap_hosts                    = try([for instance in local.ldap_instances : instance["ipv4_address"]], [])
  login_host_ip                 = try([for instance in local.login_instance : instance["ipv4_address"]], [])
  compute_inventory_path        = var.enable_deployer ? "${path.root}/../../modules/ansible-roles/compute.ini" : "${path.root}/modules/ansible-roles/compute.ini"
  compute_hosts_inventory_path  = var.enable_deployer ? "${path.root}/../../solutions/lsf/compute_hosts.ini" : "${path.root}/solutions/lsf/compute_hosts.ini"
  mgmt_hosts_inventory_path     = var.enable_deployer ? "${path.root}/../../solutions/lsf/mgmt_hosts.ini" : "${path.root}/solutions/lsf/mgmt_hosts.ini"
  bastion_hosts_inventory_path  = var.enable_deployer ? "${path.root}/../../solutions/lsf/bastion_hosts.ini" : "${path.root}/solutions/lsf/bastion_hosts.ini"
  deployer_hosts_inventory_path = var.enable_deployer ? "${path.root}/../../solutions/lsf/deployer_hosts.ini" : "${path.root}/solutions/lsf/deployer_hosts.ini"
  ldap_hosts_inventory_path     = var.enable_deployer ? "${path.root}/../../solutions/lsf/ldap_hosts.ini" : "${path.root}/solutions/lsf/ldap_hosts.ini"
  login_host_inventory_path     = var.enable_deployer ? "${path.root}/../../solutions/lsf/login_host.ini" : "${path.root}/solutions/lsf/login_host.ini"
  # storage_inventory_path = var.enable_deployer ? "${path.root}/../../modules/ansible-roles/storage.ini" : "${path.root}/modules/ansible-roles/storage.ini"
}

# locals needed for playbook
locals {
  bastion_fip              = module.deployer.bastion_fip
  compute_private_key_path = var.enable_deployer ? "${path.root}/../../modules/ansible-roles/compute_id_rsa" : "${path.root}/modules/ansible-roles/compute_id_rsa" #checkov:skip=CKV_SECRET_6
  # storage_private_key_path = var.enable_deployer ? "${path.root}/../../modules/ansible-roles/storage_id_rsa" : "${path.root}/modules/ansible-roles/storage_id_rsa" #checkov:skip=CKV_SECRET_6
  observability_playbook_path = var.enable_deployer ? "${path.root}/../../modules/ansible-roles/observability.yaml" : "${path.root}/modules/ansible-roles/observability.yaml"
  lsf_mgmt_playbooks_path     = var.enable_deployer ? "${path.root}/../../modules/ansible-roles/lsf_mgmt_config.yml" : "${path.root}/modules/ansible-roles/lsf_mgmt_config.yml"
  playbooks_path              = var.enable_deployer ? "${path.root}/../../modules/ansible-roles/" : "${path.root}/modules/ansible-roles"
  # storage_playbook_path = var.enable_deployer ? "${path.root}/../../modules/ansible-roles/storage_ssh.yaml" : "${path.root}/modules/ansible-roles/storage_ssh.yaml"
}

# file Share OutPut
locals {
  cloud_logs_ingress_private_endpoint = var.enable_deployer ? "" : module.cloud_monitoring_instance_creation[0].cloud_logs_ingress_private_endpoint
}

# details needed for json file
locals {
  compute_instances_data = var.scheduler == "LSF" ? var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].compute_vsi_data]) : []
  compute_hosts_ips      = var.scheduler == "LSF" ? var.enable_deployer ? [] : local.compute_instances_data[*]["ipv4_address"] : []
  # bastion_instances_data = var.scheduler == "LSF" ? var.enable_deployer ? flatten([module.deployer.bastion_vsi_data]) : [] : []
  bastion_hosts_ips   = var.scheduler == "LSF" ? var.enable_deployer ? [module.deployer.bastion_fip] : [] : []
  deployer_hosts_ips  = var.scheduler == "LSF" ? var.enable_deployer ? [module.deployer.deployer_ip] : [] : []
  mgmt_instances_data = var.scheduler == "LSF" ? var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].management_vsi_data]) : []
  mgmt_hosts_ips      = var.scheduler == "LSF" ? var.enable_deployer ? [] : local.mgmt_instances_data[*]["ipv4_address"] : []
  ldap_hosts_ips      = var.scheduler == "LSF" ? var.enable_deployer ? [] : (var.enable_ldap == true ? (var.ldap_server == "null" ? local.ldap_instances[*]["ipv4_address"] : [var.ldap_server]) : []) : []
  json_inventory_path = var.enable_deployer ? "${path.root}/../../modules/ansible-roles/all.json" : "${path.root}/modules/ansible-roles/all.json"
  management_nodes    = var.scheduler == "LSF" ? var.enable_deployer ? [] : (flatten([module.landing_zone_vsi[0].management_vsi_data]))[*]["name"] : []
  login_host          = var.scheduler == "LSF" ? var.enable_deployer ? [] : (flatten([module.landing_zone_vsi[0].login_vsi_data]))[*]["name"] : []
  compute_nodes = var.scheduler == "LSF" ? (
    var.enable_deployer ? [] : flatten([module.landing_zone_vsi[0].compute_vsi_data])[*]["name"]
  ) : []

  compute_nodes_list = var.scheduler == "LSF" ? (
    var.enable_deployer ? [] : (
      length(local.compute_nodes) == 0 ? [] : distinct(flatten([
        for prefix, nodes in {
          for node in local.compute_nodes :
          join("-", slice(split("-", node), 0, length(split("-", node)) - 1)) => node...
        } : length(nodes) > 1 ?
        [format(
          "%s-[%s:%s]",
          prefix,
          split("-", nodes[0])[length(split("-", nodes[0])) - 1],
          split("-", nodes[length(nodes) - 1])[length(split("-", nodes[length(nodes) - 1])) - 1]
        )] : nodes
      ]))
    )
  ) : []

  client_nodes          = var.scheduler == "LSF" ? var.enable_deployer ? [] : (flatten([module.landing_zone_vsi[0].client_vsi_data]))[*]["name"] : []
  gui_hosts             = var.scheduler == "LSF" ? var.enable_deployer ? [] : [local.management_nodes[0]] : [] # Without Pac HA
  db_hosts              = var.scheduler == "LSF" ? var.enable_deployer ? [] : [local.management_nodes[0]] : [] # Without Pac HA
  ha_shared_dir         = var.scheduler == "LSF" ? "/mnt/lsf" : ""
  nfs_install_dir       = var.scheduler == "LSF" ? "none" : ""
  enable_monitoring     = var.scheduler == "LSF" ? false : false
  lsf_deployer_hostname = var.scheduler == "LSF" ? var.deployer_hostname : ""

  cloud_logs_bucket    = length([for bucket in local.cos_data : bucket if strcontains(bucket.bucket_name, "logs-data-bucket")]) > 0 ? [for bucket in local.cos_data : bucket if strcontains(bucket.bucket_name, "logs-data-bucket")][0] : null
  cloud_metrics_bucket = length([for bucket in local.cos_data : bucket if strcontains(bucket.bucket_name, "metrics-data-bucket")]) > 0 ? [for bucket in local.cos_data : bucket if strcontains(bucket.bucket_name, "metrics-data-bucket")][0] : null
  cloud_logs_data_bucket = jsonencode(local.cloud_logs_bucket != null ? {
    bucket_crn      = local.cloud_logs_bucket.crn
    bucket_endpoint = local.cloud_logs_bucket.s3_endpoint_direct
  } : null)
  cloud_metrics_data_bucket = jsonencode(local.cloud_metrics_bucket != null ? {
    bucket_crn      = local.cloud_metrics_bucket.crn
    bucket_endpoint = local.cloud_metrics_bucket.s3_endpoint_direct
  } : null)
  # scc_cos_bucket       = length(module.landing_zone.cos_buckets_names) > 0 && var.scc_enable ? [for name in module.landing_zone.cos_buckets_names : name if strcontains(name, "scc-bucket")][0] : ""
  # scc_cos_instance_crn = length(module.landing_zone.cos_instance_crns) > 0 && var.scc_enable ? module.landing_zone.cos_instance_crns[0] : ""

  compute_subnet_crn          = var.enable_deployer ? "" : data.ibm_is_subnet.compute_subnet_crn[0].crn
  ssh_keys_ids                = var.enable_deployer ? [] : [for name in var.ssh_keys : data.ibm_is_ssh_key.ssh_keys[name].id]
  compute_public_key_content  = var.enable_deployer ? "" : jsonencode(base64encode(join("", flatten([module.landing_zone_vsi[0].compute_public_key_content]))))
  compute_private_key_content = var.enable_deployer ? "" : jsonencode(base64encode(join("", flatten([module.landing_zone_vsi[0].compute_private_key_content]))))

  mgmnt_host_entry    = var.scheduler == "LSF" ? { for vsi in flatten([module.landing_zone_vsi[*].management_vsi_data]) : vsi.ipv4_address => vsi.name } : {}
  comp_host_entry     = var.scheduler == "LSF" ? { for vsi in flatten([module.landing_zone_vsi[*].compute_vsi_data]) : vsi.ipv4_address => vsi.name } : {}
  login_host_entry    = var.scheduler == "LSF" ? { for vsi in flatten([module.landing_zone_vsi[*].login_vsi_data]) : vsi.ipv4_address => vsi.name } : {}
  deployer_host_entry = var.scheduler == "LSF" ? { for inst in local.deployer_instances : inst.ipv4_address => inst.name if inst.ipv4_address != null } : {}
}

locals {
  # gpfs_base_rpm_path  = fileset(var.spectrumscale_rpms_path, "gpfs.base-*")
  # scale_org_version   = regex("gpfs.base-(.*).x86_64.rpm", tolist(local.gpfs_base_rpm_path)[0])[0]
  scale_version = "5.2.2.1" #replace(local.scale_org_version, "-", ".")

  compute_vsi_profile    = var.static_compute_instances[*]["profile"]
  storage_vsi_profile    = var.storage_instances[*]["profile"]
  storage_bms_profile    = var.storage_servers[*]["profile"]
  management_vsi_profile = var.management_instances[*]["profile"]
  afm_vsi_profile        = var.afm_instances[*]["profile"]
  protocol_vsi_profile   = var.protocol_instances[*]["profile"]
  afm_server_type        = strcontains(local.afm_vsi_profile[0], "metal")
  ces_server_type        = strcontains(local.protocol_vsi_profile[0], "metal")

  scale_ces_enabled            = local.protocol_instance_count > 0 ? true : false
  is_colocate_protocol_subset  = local.scale_ces_enabled && var.colocate_protocol_instances ? local.protocol_instance_count < local.storage_instance_count ? true : false : false
  enable_sec_interface_compute = local.scale_ces_enabled == false && data.ibm_is_instance_profile.compute_profile.bandwidth[0].value >= 64000 ? true : false
  enable_sec_interface_storage = local.scale_ces_enabled == false && var.storage_type != "persistent" && data.ibm_is_instance_profile.storage_profile.bandwidth[0].value >= 64000 ? true : false
  enable_mrot_conf             = local.enable_sec_interface_compute && local.enable_sec_interface_storage ? true : false
  enable_afm                   = sum(var.afm_instances[*]["count"]) > 0 ? true : false

  compute_instance_private_ips = flatten(local.compute_instances[*]["ipv4_address"])
  compute_instance_ids         = flatten(local.compute_instances[*]["id"])
  compute_instance_names       = try(tolist([for name_details in flatten(local.compute_instances[*]["name"]) : "${name_details}.${var.dns_domain_names["compute"]}"]), [])

  compute_mgmt_instance_private_ips = flatten(local.comp_mgmt_instances[*]["ipv4_address"])
  compute_mgmt_instance_ids         = flatten(local.comp_mgmt_instances[*]["id"])
  compute_mgmt_instance_names       = try(tolist([for name_details in flatten(local.comp_mgmt_instances[*]["name"]) : "${name_details}.${var.dns_domain_names["compute"]}"]), [])

  strg_instance_private_ips = flatten(local.storage_instances[*]["ipv4_address"])
  strg_instance_ids         = flatten(local.storage_instances[*]["id"])
  strg_instance_names       = try(tolist([for name_details in flatten(local.storage_instances[*]["name"]) : "${name_details}.${var.dns_domain_names["storage"]}"]), [])

  strg_servers_private_ips = flatten(local.storage_servers[*]["ipv4_address"])
  strg_servers_ids         = flatten(local.storage_servers[*]["id"])
  strg_servers_names       = try(tolist([for name_details in flatten(local.storage_servers[*]["name"]) : "${name_details}.${var.dns_domain_names["storage"]}"]), [])

  strg_mgmt_instance_private_ips = flatten(local.strg_mgmt_instances[*]["ipv4_address"])
  strg_mgmtt_instance_ids        = flatten(local.strg_mgmt_instances[*]["id"])
  strg_mgmt_instance_names       = try(tolist([for name_details in flatten(local.strg_mgmt_instances[*]["name"]) : "${name_details}.${var.dns_domain_names["storage"]}"]), [])

  strg_tie_breaker_private_ips    = flatten(local.tie_brkr_instances[*]["ipv4_address"])
  strg_tie_breaker_instance_ids   = flatten(local.tie_brkr_instances[*]["id"])
  strg_tie_breaker_instance_names = try(tolist([for name_details in flatten(local.tie_brkr_instances[*]["name"]) : "${name_details}.${var.dns_domain_names["storage"]}"]), [])

  secondary_compute_instance_private_ips = flatten(local.compute_instances[*]["secondary_ipv4_address"])
  # secondary_storage_instance_private_ips = flatten(local.storage_instances[*]["secondary_ipv4_address"])

  protocol_instance_private_ips = flatten(local.protocol_instances[*]["ipv4_address"])
  protocol_instance_ids         = flatten(local.protocol_instances[*]["id"])
  protocol_instance_names       = try(tolist([for name_details in flatten(local.protocol_instances[*]["name"]) : "${name_details}.${var.dns_domain_names["storage"]}"]), [])

  protocol_cluster_instance_names = var.enable_deployer ? [] : slice((concat(local.protocol_instance_names, (var.storage_type == "persistent" ? [] : local.strg_instance_names))), 0, local.protocol_instance_count)

  # client_instance_private_ips = flatten(local.client_instances[*]["ipv4_address"])
  # client_instance_ids         = flatten(local.client_instances[*]["id"])
  client_instance_names = try(tolist([for name_details in flatten(local.client_instances[*]["name"]) : "${name_details}.${var.dns_domain_names["client"]}"]), [])

  gklm_instance_private_ips = flatten(local.gklm_instances[*]["ipv4_address"])
  # gklm_instance_ids         = flatten(local.gklm_instances[*]["id"])
  # gklm_instance_names       = try(tolist([for name_details in flatten(local.gklm_instances[*]["name"]) : "${name_details}.${var.dns_domain_names["storage"]}"]), [])

  ldap_instance_private_ips = flatten(local.ldap_instances[*]["ipv4_address"])
  # ldap_instance_ids         = flatten(local.ldap_instances[*]["id"])
  # ldap_instance_names       = flatten(local.ldap_instances[*]["name"])
}

locals {
  afm_instance_private_ips = flatten(local.afm_instances[*]["ipv4_address"])
  afm_instance_ids         = flatten(local.afm_instances[*]["id"])
  afm_instance_names       = try(tolist([for name_details in flatten(local.afm_instances[*]["name"]) : "${name_details}.${var.dns_domain_names["storage"]}"]), [])

  new_instance_bucket_hmac        = [for details in var.afm_cos_config : details if(details.cos_instance == "" && details.bucket_name == "" && details.cos_service_cred_key == "")]
  exstng_instance_new_bucket_hmac = [for details in var.afm_cos_config : details if(details.cos_instance != "" && details.bucket_name == "" && details.cos_service_cred_key == "")]
  exstng_instance_bucket_new_hmac = [for details in var.afm_cos_config : details if(details.cos_instance != "" && details.bucket_name != "" && details.cos_service_cred_key == "")]
  exstng_instance_hmac_new_bucket = [for details in var.afm_cos_config : details if(details.cos_instance != "" && details.bucket_name == "" && details.cos_service_cred_key != "")]
  exstng_instance_bucket_hmac     = [for details in var.afm_cos_config : details if(details.cos_instance != "" && details.bucket_name != "" && details.cos_service_cred_key != "")]

  afm_cos_bucket_details = local.enable_afm == true ? flatten(module.cos[*].afm_cos_bucket_details) : []
  afm_cos_config         = local.enable_afm == true ? flatten(module.cos[*].afm_config_details) : []
}


locals {

  storage_instance_private_ips = var.storage_type != "persistent" ? local.enable_afm == true ? concat(local.strg_instance_private_ips, local.afm_instance_private_ips) : local.strg_instance_private_ips : []
  storage_instance_ids         = var.storage_type != "persistent" ? local.enable_afm == true ? concat(local.strg_instance_ids, local.afm_instance_ids) : local.strg_instance_ids : []
  storage_instance_names       = var.storage_type != "persistent" ? local.enable_afm == true ? concat(local.strg_instance_names, local.afm_instance_names) : local.strg_instance_names : []
  storage_ips_with_vol_mapping = module.landing_zone_vsi[*].instance_ips_with_vol_mapping

  storage_cluster_instance_private_ips = local.scale_ces_enabled == false ? local.storage_instance_private_ips : concat(local.storage_instance_private_ips, local.protocol_instance_private_ips)
  storage_cluster_instance_ids         = local.scale_ces_enabled == false ? local.storage_instance_ids : concat(local.storage_instance_ids, local.protocol_instance_ids)
  storage_cluster_instance_names       = local.scale_ces_enabled == false ? local.storage_instance_names : concat(local.storage_instance_names, local.protocol_instance_names)

  baremetal_instance_private_ips = var.storage_type == "persistent" ? local.enable_afm == true ? concat(local.strg_servers_private_ips, local.afm_instance_private_ips) : local.strg_servers_private_ips : []
  baremetal_instance_ids         = var.storage_type == "persistent" ? local.enable_afm == true ? concat(local.strg_servers_ids, local.afm_instance_ids) : local.strg_servers_ids : []
  baremetal_instance_names       = var.storage_type == "persistent" ? local.enable_afm == true ? concat(local.strg_servers_names, local.afm_instance_names) : local.strg_servers_names : []

  baremetal_cluster_instance_private_ips = var.storage_type == "persistent" && local.scale_ces_enabled == false ? local.baremetal_instance_private_ips : concat(local.baremetal_instance_private_ips, local.protocol_instance_private_ips)
  baremetal_cluster_instance_ids         = var.storage_type == "persistent" && local.scale_ces_enabled == false ? local.baremetal_instance_ids : concat(local.baremetal_instance_ids, local.protocol_instance_ids)
  baremetal_cluster_instance_names       = var.storage_type == "persistent" && local.scale_ces_enabled == false ? local.baremetal_instance_names : concat(local.baremetal_instance_names, local.protocol_instance_names)

  tie_breaker_storage_instance_private_ips = var.storage_type != "persistent" ? local.strg_tie_breaker_private_ips : local.baremetal_instance_private_ips
  tie_breaker_storage_instance_ids         = var.storage_type != "persistent" ? local.strg_tie_breaker_instance_ids : local.baremetal_instance_ids
  tie_breaker_storage_instance_names       = var.storage_type != "persistent" ? local.strg_tie_breaker_instance_names : local.baremetal_instance_names
  tie_breaker_ips_with_vol_mapping         = module.landing_zone_vsi[*].instance_ips_with_vol_mapping_tie_breaker

  storage_subnet_cidr = var.enable_deployer ? "" : local.storage_instance_count > 0 ? jsonencode((data.ibm_is_subnet.existing_storage_subnets[*].ipv4_cidr_block)[0]) : ""
  cluster_subnet_cidr = var.enable_deployer ? "" : jsonencode((data.ibm_is_subnet.existing_cluster_subnets[*].ipv4_cidr_block)[0])
  client_subnet_cidr  = var.enable_deployer ? "" : local.client_instance_count > 0 ? jsonencode((data.ibm_is_subnet.existing_client_subnets[*].ipv4_cidr_block)[0]) : ""

  compute_memory               = data.ibm_is_instance_profile.compute_profile.memory[0].value
  compute_vcpus_count          = data.ibm_is_instance_profile.compute_profile.vcpu_count[0].value
  compute_bandwidth            = data.ibm_is_instance_profile.compute_profile.bandwidth[0].value
  management_memory            = data.ibm_is_instance_profile.management_profile.memory[0].value
  management_vcpus_count       = data.ibm_is_instance_profile.management_profile.vcpu_count[0].value
  management_bandwidth         = data.ibm_is_instance_profile.management_profile.bandwidth[0].value
  storage_desc_memory          = data.ibm_is_instance_profile.storage_profile.memory[0].value
  storage_desc_vcpus_count     = data.ibm_is_instance_profile.storage_profile.vcpu_count[0].value
  storage_desc_bandwidth       = data.ibm_is_instance_profile.storage_profile.bandwidth[0].value
  storage_memory               = var.storage_type == "persistent" ? data.ibm_is_bare_metal_server_profile.storage_bms_profile[0].memory[0].value : data.ibm_is_instance_profile.storage_profile.memory[0].value
  storage_vcpus_count          = var.storage_type == "persistent" ? data.ibm_is_bare_metal_server_profile.storage_bms_profile[0].cpu_core_count[0].value : data.ibm_is_instance_profile.storage_profile.vcpu_count[0].value
  storage_bandwidth            = var.storage_type == "persistent" ? data.ibm_is_bare_metal_server_profile.storage_bms_profile[0].bandwidth[0].value : data.ibm_is_instance_profile.storage_profile.bandwidth[0].value
  protocol_memory              = (local.scale_ces_enabled == true && var.colocate_protocol_instances == false) ? local.ces_server_type == false ? data.ibm_is_instance_profile.protocol_profile[0].memory[0].value : jsonencode(0) : jsonencode(0)
  protocol_vcpus_count         = (local.scale_ces_enabled == true && var.colocate_protocol_instances == false) ? local.ces_server_type == false ? data.ibm_is_instance_profile.protocol_profile[0].vcpu_count[0].value : jsonencode(0) : jsonencode(0)
  protocol_bandwidth           = (local.scale_ces_enabled == true && var.colocate_protocol_instances == false) ? local.ces_server_type == false ? data.ibm_is_instance_profile.protocol_profile[0].bandwidth[0].value : jsonencode(0) : jsonencode(0)
  storage_protocol_memory      = var.storage_type == "persistent" ? data.ibm_is_bare_metal_server_profile.storage_bms_profile[0].memory[0].value : data.ibm_is_instance_profile.storage_profile.memory[0].value
  storage_protocol_vcpus_count = var.storage_type == "persistent" ? data.ibm_is_bare_metal_server_profile.storage_bms_profile[0].cpu_core_count[0].value : data.ibm_is_instance_profile.storage_profile.vcpu_count[0].value
  storage_protocol_bandwidth   = var.storage_type == "persistent" ? data.ibm_is_bare_metal_server_profile.storage_bms_profile[0].bandwidth[0].value : data.ibm_is_instance_profile.storage_profile.bandwidth[0].value
  afm_memory                   = local.afm_server_type == true ? jsonencode("") : data.ibm_is_instance_profile.afm_server_profile[0].memory[0].value
  afm_vcpus_count              = local.afm_server_type == true ? jsonencode("") : data.ibm_is_instance_profile.afm_server_profile[0].vcpu_count[0].value
  afm_bandwidth                = local.afm_server_type == true ? jsonencode("") : data.ibm_is_instance_profile.afm_server_profile[0].bandwidth[0].value

  protocol_reserved_name_ips_map = try({ for details in data.ibm_is_subnet_reserved_ips.protocol_subnet_reserved_ips[0].reserved_ips : details.name => details.address }, {})
  protocol_subnet_gateway_ip     = local.scale_ces_enabled == true ? local.protocol_reserved_name_ips_map.ibm-default-gateway : ""
}

# Existing bastion Variables
locals {
  bastion_instance_public_ip = var.existing_bastion_instance_name != null ? var.existing_bastion_instance_public_ip : null
  bastion_ssh_private_key    = var.existing_bastion_instance_name != null ? var.existing_bastion_ssh_private_key : null
}

locals {
  existing_vpc_cidr = var.vpc_name != null ? data.ibm_is_vpc_address_prefixes.existing_vpc_cidr[0].address_prefixes[0].cidr : null
  cluster_cidr      = var.vpc_name == null ? var.vpc_cidr : local.existing_vpc_cidr
}

# locals needed for ssh connection
locals {
  ssh_forward_host = var.enable_deployer ? "" : local.mgmt_hosts_ips[0]
  ssh_forwards     = var.enable_deployer ? "" : "-L 8443:${local.ssh_forward_host}:8443 -L 6080:${local.ssh_forward_host}:6080 -L 8444:${local.ssh_forward_host}:8444"
  ssh_jump_host    = var.enable_deployer ? "" : local.bastion_instance_public_ip != null ? local.bastion_instance_public_ip : var.bastion_fip
  ssh_jump_option  = var.enable_deployer ? "" : "-J ubuntu@${local.ssh_jump_host}"
  ssh_cmd          = var.enable_deployer ? "" : "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=5 -o ServerAliveCountMax=1 ${local.ssh_forwards} ${local.ssh_jump_option} lsfadmin@${join(",", local.login_host_ip)}"
}

#locals {
#  cloud_monitoring_instance_crn = var.observability_monitoring_enable ? module.cloud_monitoring_instance_creation.cloud_monitoring_crn : null
#}

# locals {
#   cloud_monitoring_instance_crn = var.enable_deployer ? "" : var.observability_monitoring_enable && length(module.cloud_monitoring_instance_creation) > 0 ? module.cloud_monitoring_instance_creation[0].cloud_monitoring_crn : null
# }
