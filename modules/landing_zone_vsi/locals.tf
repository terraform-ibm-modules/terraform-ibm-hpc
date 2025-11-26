# define variables
locals {
  # Future use
  name           = lower(var.scheduler)
  prefix         = var.prefix
  tags           = [local.prefix, local.name]
  vsi_interfaces = ["eth0", "eth1"]
  bms_interfaces = ["eth0", "eth1"]
  # bms_interfaces = ["ens1", "ens2"]
  # TODO: explore (DA always keep it true)
  skip_iam_authorization_policy = true
  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))

  # management_image_id = data.ibm_is_image.management_stock_image[*].id
  # Check whether an entry is found in the mapping file for the given management node image
  image_mapping_entry_found = contains(keys(local.image_region_map), var.management_instances[0]["image"])
  new_image_id              = local.image_mapping_entry_found ? local.image_region_map[var.management_instances[0]["image"]][local.region] : "Image not found with the given name"

  # compute_image_id = data.ibm_is_image.compute_stock_image[*].id
  # Check whether an entry is found in the mapping file for the given compute node image
  compute_image_found_in_map = contains(keys(local.image_region_map), var.static_compute_instances[0]["image"])
  # If not found, assume the name is the id already (customer provided image)
  new_compute_image_id = local.compute_image_found_in_map ? local.image_region_map[var.static_compute_instances[0]["image"]][local.region] : "Image not found with the given name"

  # login_image_id = data.ibm_is_image.login_vsi_image[*].id
  # Check whether an entry is found in the mapping file for the given login node image
  login_image_found_in_map = contains(keys(local.image_region_map), var.login_instance[0]["image"])
  # If not found, assume the name is the id already (customer provided image)
  new_login_image_id = local.login_image_found_in_map ? local.image_region_map[var.login_instance[0]["image"]][local.region] : "Image not found with the given name"

  scale_storage_image_found_in_map = contains(keys(local.storage_image_region_map), var.storage_instances[0]["image"])
  evaluation_image_id              = local.evaluation_image_region_map[one(keys(local.evaluation_image_region_map))][local.region]
  new_storage_image_id             = var.storage_type != "evaluation" ? (local.scale_storage_image_found_in_map ? local.storage_image_region_map[var.storage_instances[0]["image"]][local.region] : "Image not found with the given name") : local.evaluation_image_id

  storage_bare_metal_image_mapping_entry_found = contains(keys(local.storage_image_region_map), var.storage_servers[0]["image"])
  storage_bare_metal_image_id                  = local.storage_bare_metal_image_mapping_entry_found ? local.storage_image_region_map[var.storage_servers[0]["image"]][local.region] : "Image not found with the given name"

  scale_encryption_image_mapping_entry_found = contains(keys(local.encryption_image_region_map), var.gklm_instances[0]["image"])
  scale_encryption_image_id                  = (var.scale_encryption_enabled == true && var.scale_encryption_type == "gklm") ? (local.scale_encryption_image_mapping_entry_found ? local.encryption_image_region_map[var.gklm_instances[0]["image"]][local.region] : "Image not found with the given name") : "Either encryption is not enabled or encryption type is not gklm"

  scale_compute_image_found_in_map = contains(keys(local.storage_image_region_map), var.static_compute_instances[0]["image"])
  scale_compute_image_id           = local.scale_compute_image_found_in_map ? local.storage_image_region_map[var.static_compute_instances[0]["image"]][local.region] : "Image not found with the given name"

  products = var.scheduler == "Scale" ? "scale" : "lsf"
  block_storage_volumes = [for volume in coalesce(var.nsd_details, []) : {
    name           = format("nsd-%s", index(var.nsd_details, volume) + 1)
    profile        = volume["profile"]
    capacity       = volume["capacity"]
    iops           = volume["iops"]
    resource_group = var.resource_group
    # TODO: Encryption
    # encryption_key =
  }]
  # TODO: Update the LB configurable
  # Bug: 5847 - LB profile & subnets are not configurable
  /*
  load_balancers = [{
    name              = "hpc"
    type              = "private"
    listener_port     = 80
    listener_protocol = "http"
    connection_limit  = 10
    algorithm         = "round_robin"
    protocol          = "http"
    health_delay      = 60
    health_retries    = 5
    health_timeout    = 30
    health_type       = "http"
    pool_member_port  = 80
  }]
  */

  client_instance_count         = sum(var.client_instances[*]["count"])
  management_instance_count     = sum(var.management_instances[*]["count"])
  storage_instance_count        = var.storage_type == "persistent" ? sum(var.storage_servers[*]["count"]) : sum(var.storage_instances[*]["count"])
  protocol_instance_count       = sum(var.protocol_instances[*]["count"])
  static_compute_instance_count = sum(var.static_compute_instances[*]["count"])
  afm_instances_count           = sum(var.afm_instances[*]["count"])

  enable_client     = local.client_instance_count > 0
  enable_management = local.management_instance_count > 0
  enable_compute    = local.management_instance_count > 0 || local.static_compute_instance_count > 0
  enable_storage    = local.storage_instance_count > 0
  enable_protocol   = local.storage_instance_count > 0 && local.protocol_instance_count > 0
  enable_afm        = local.afm_instances_count > 0
  # TODO: Fix the logic
  enable_block_storage = var.storage_type == "scratch" ? true : false

  # Future use
  # TODO: Fix the logic
  # enable_load_balancer = false

  client_node_name              = format("%s-%s", local.prefix, "client")
  management_node_name          = format("%s-%s", local.prefix, "mgmt")
  compute_node_name             = format("%s-%s", local.prefix, "comp")
  storage_node_name             = format("%s-%s", local.prefix, "strg")
  storage_tie_breaker_node_name = format("%s-%s", local.prefix, "strg-tie")
  protocol_node_name            = format("%s-%s", local.prefix, "proto")
  storage_management_node_name  = format("%s-%s", local.prefix, "strg-mgmt")
  ldap_node_name                = format("%s-%s", local.prefix, "ldap")
  afm_node_name                 = format("%s-%s", local.prefix, "afm")
  gklm_node_name                = format("%s-%s", local.prefix, "gklm")
  compute_management_node_name  = format("%s-%s", local.prefix, "comp-mgmt")
  login_node_name               = format("%s-%s", local.prefix, "login")

  # Future use
  /*
  management_instance_count     = sum(var.management_instances[*]["count"])
  management_instance_profile   = flatten([for item in var.management_instances: [
    for count in range(item["count"]) : var.management_instances[index(var.management_instances, item)]["profile"]
  ]])
  static_compute_instance_count = sum(var.static_compute_instances[*]["count"])
  storage_instance_count        = sum(var.storage_instances[*]["count"])
  protocol_instance_count       = sum(var.protocol_instances[*]["count"])
  */

  # Future use
  /*
  client_image_name     = var.client_image_name
  management_image_name = var.management_image_name
  compute_image_name    = var.compute_image_name
  storage_image_name    = var.storage_image_name
  protocol_image_name   = var.storage_image_name
  */

  # client_image_id   = data.ibm_is_image.client[*].id
  # storage_image_id  = data.ibm_is_image.storage[*].id
  # protocol_image_id = data.ibm_is_image.storage[*].id
  ldap_image_id = data.ibm_is_image.ldap_vsi_image[*].id
  # afm_image_id      = data.ibm_is_image.afm[*].id
  # gklm_image_id     = data.ibm_is_image.gklm[*].id

  ssh_keys = [for name in var.ssh_keys : data.ibm_is_ssh_key.ssh_keys[name].id]
  #ldap_ssh_keys = [for name in var.ldap_instance_key_pair : data.ibm_is_ssh_key.ldap[name].id]
  # gklm_ssh_keys = [for name in var.gklm_instance_key_pair : data.ibm_is_ssh_key.gklm[name].id]

  # Future use
  /*
  # Scale static configs
  scale_cloud_deployer_path     = "/opt/IBM/ibm-spectrumscale-cloud-deploy"
  scale_cloud_install_repo_url  = "https://github.com/IBM/ibm-spectrum-scale-cloud-install"
  scale_cloud_install_repo_name = "ibm-spectrum-scale-cloud-install"
  scale_cloud_install_branch    = "5.1.8.1"
  scale_cloud_infra_repo_url    = "https://github.com/IBM/ibm-spectrum-scale-install-infra"
  scale_cloud_infra_repo_name   = "ibm-spectrum-scale-install-infra"
  scale_cloud_infra_repo_tag    = "v2.7.0"
  */

  # Region and Zone calculations
  # region = join("-", slice(split("-", var.zones[0]), 0, 2))

  # TODO: DNS configs
  # Security group rules
  # client_security_group = local.enable_client ? module.client_sg[0].security_group_id : null
  # compute_security_group = local.enable_compute ? module.compute_sg[0].security_group_id : null
  # storage_security_group = local.enable_storage ? module.storage_sg[0].security_group_id : null

  # client_security_group_remote  = compact([var.bastion_security_group_id])
  # compute_security_group_remote = compact([var.bastion_security_group_id])
  # storage_security_group_remote = compact([var.bastion_security_group_id])

  # Derived configs
  # VPC
  # resource_group_id = data.ibm_resource_group.existing_resource_group.id

  # Subnets
  # TODO: Multi-zone multi-vNIC VSIs deployment support (bug #https://github.ibm.com/GoldenEye/issues/issues/5830)
  # Findings: Singe zone multi-vNICs VSIs deployment & multi-zone single vNIC VSIs deployment are supported.
  client_subnets    = var.client_subnets
  compute_subnet_id = var.compute_subnet_id
  storage_subnets   = var.storage_subnets
  protocol_subnets  = var.protocol_subnets

  compute_public_key_content  = one(module.compute_key[*].public_key_content)
  compute_private_key_content = one(module.compute_key[*].private_key_content)

  storage_public_key_content  = one(module.storage_key[*].public_key_content)
  storage_private_key_content = one(module.storage_key[*].private_key_content)

  client_public_key_content  = one(module.client_key[*].public_key_content)
  client_private_key_content = one(module.client_key[*].private_key_content)

  protocol_vsi_profile = var.protocol_instances[*]["profile"]
  ces_server_type      = strcontains(local.protocol_vsi_profile[0], "metal")
  afm_vsi_profile      = var.afm_instances[*]["profile"]
  afm_server_type      = strcontains(local.afm_vsi_profile[0], "metal")

  sapphire_rapids_profile_check = strcontains(local.protocol_vsi_profile[0], "3-metal") || strcontains(local.protocol_vsi_profile[0], "3d-metal")

  tie_breaker_bm_server = [{
    profile    = var.tie_breaker_bm_server_profile == null ? (var.storage_servers[*]["profile"])[0] : var.tie_breaker_bm_server_profile
    count      = 1
    image      = (var.storage_servers[*]["image"])[0]
    filesystem = (var.storage_servers[*]["filesystem"])[0]
  }]

  user_data_vars = {
    dns_domain                  = var.dns_domain_names["storage"],
    enable_protocol             = local.enable_protocol,
    protocol_domain             = var.dns_domain_names["protocol"],
    vpc_region                  = var.vpc_region,
    protocol_subnet_id          = length(var.protocol_subnets) == 0 ? "" : var.protocol_subnets[0].id,
    resource_group_id           = var.resource_group,
    bastion_public_key_content  = base64encode(var.bastion_public_key_content != null ? var.bastion_public_key_content : ""),
    storage_private_key_content = var.scheduler == "Scale" ? base64encode(module.storage_key[0].private_key_content) : "",
    storage_public_key_content  = var.scheduler == "Scale" ? base64encode(module.storage_key[0].public_key_content) : ""
  }

  enable_sec_interface_compute = local.enable_protocol == false && data.ibm_is_instance_profile.compute_profile[0].bandwidth[0].value >= 64000 ? true : false
  enable_sec_interface_storage = local.enable_protocol == false && var.storage_type != "persistent" && data.ibm_is_instance_profile.storage[0].bandwidth[0].value >= 64000 ? true : false

  # Security Groups
  protocol_secondary_security_group = distinct(flatten([
    for subnet_index, subnet in local.protocol_subnets : [
      for i in range(var.protocol_instances[subnet_index]["count"]) : {
        security_group_id = one(var.storage_security_group_name == null ? module.storage_sg[*].security_group_id : local.storage_security_group_name_id)
        interface_name    = subnet["name"]
      }
    ]
  ]))

  storage_secondary_security_group = distinct(flatten([
    for subnet_index, subnet in local.storage_subnets : [
      for i in range(var.static_compute_instances[subnet_index]["count"]) : {
        security_group_id = one(module.storage_sg[*].security_group_id)
        interface_name    = subnet["name"]
      }
    ]
  ]))

  # ldap_instance_image_id = var.enable_ldap == true && var.ldap_server == "null" ? data.ibm_is_image.ldap_vsi_image[0].id : "null"
}

locals {

  # Getting current/available dedicated host profiles
  current_dh_profiles = var.enable_dedicated_host ? [for p in data.ibm_is_dedicated_host_profiles.profiles[0].profiles : p if p.status == "current"] : []

  # Get valid instance profiles from available dedicated hosts
  valid_instance_profiles = toset(distinct(flatten([
    for p in local.current_dh_profiles : p.supported_instance_profiles[*].name
  ])))

  # Extract profile family prefix (e.g., "bx2" from "bx2-16x64")
  instance_profile_prefixes = distinct([
    for inst in var.static_compute_instances :
    regex("^([a-z]+[0-9]+)", inst.profile)[0]
  ])

  # Map instance profile prefixes to available dedicated host profiles
  profile_mappings = {
    for prefix in local.instance_profile_prefixes :
    prefix => {
      dh_profiles = [
        for p in local.current_dh_profiles :
        p if startswith(p.name, "${prefix}-host")
      ]
    }
  }

  # Validate each instance configuration
  validation_results = [
    for inst in var.static_compute_instances : {
      profile              = inst.profile
      profile_prefix       = regex("^([a-z]+[0-9]+)", inst.profile)[0]
      count                = inst.count
      instance_valid       = contains(local.valid_instance_profiles, inst.profile)
      dh_profile_available = length(local.profile_mappings[regex("^([a-z]+[0-9]+)", inst.profile)[0]].dh_profiles) > 0
    } if inst.count > 0
  ]

  # Error messages for invalid configurations
  errors = concat(
    [
      for vr in local.validation_results :
      "ERROR: Dedicated Host for the instance profile '${vr.profile}' is not available in this region"
      if !vr.instance_valid
    ],
    [
      for vr in local.validation_results :
      "ERROR: No CURRENT dedicated host profile available for '${vr.profile_prefix}-host-*' (required for '${vr.profile}')"
      if vr.instance_valid && !vr.dh_profile_available
    ]
  )

  # Create one dedicated host config per instance profile (not per count)
  dedicated_host_config = {
    for vr in local.validation_results :
    vr.profile => {
      class   = vr.profile_prefix
      profile = local.profile_mappings[vr.profile_prefix].dh_profiles[0].name
      family  = local.profile_mappings[vr.profile_prefix].dh_profiles[0].family
      count   = vr.count
    }
    if vr.instance_valid && vr.dh_profile_available
  }

  dedicated_host_ids = [
    for instance in var.static_compute_instances : {
      profile = instance.profile
      id      = try(one(module.dedicated_host[instance.profile].dedicated_host_id), "")
    }
  ]

  dedicated_host_map = { for instance in local.dedicated_host_ids : instance.profile => instance.id }

}

# Validating profile configurations
locals {
  should_validate_profile = var.enable_dedicated_host && length(local.errors) > 0
}

check "profile_validation" {
  assert {
    condition = !local.should_validate_profile
    error_message = join("\n", concat(
      ["Deployment configuration invalid:"],
      local.errors,
      ["", "Available CURRENT dedicated host profiles in this region:"],
      [for p in local.current_dh_profiles : " - ${p.name} (${p.family})"]
    ))
  }
}

locals {

  bastion_security_group = var.bastion_security_group_id
  # Security group id
  client_security_group  = local.client_instance_count > 0 ? (local.enable_client && var.client_security_group_name == null ? module.client_sg[0].security_group_id_for_ref : local.client_security_group_name_id[0]) : ""
  compute_security_group = local.static_compute_instance_count > 0 ? (local.enable_compute && var.compute_security_group_name == null ? module.compute_sg[0].security_group_id_for_ref : local.compute_security_group_name_id[0]) : ""
  storage_security_group = local.storage_instance_count > 0 ? (local.enable_storage && var.storage_security_group_name == null ? module.storage_sg[0].security_group_id_for_ref : local.storage_security_group_name_id[0]) : ""

  client_security_group_rules = local.enable_client ? (local.enable_compute ?
    [
      { name = "client-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "client-allow-clientsg-inbound", direction = "inbound", remote = local.client_security_group },
      { name = "client-allow-computesg-inbound", direction = "inbound", remote = local.compute_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr },
      { name = "storage-allow-storagesg-inbound", direction = "inbound", remote = local.storage_security_group },
      { name = "client-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" }
    ] :
    [
      { name = "client-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "client-allow-clientsg-inbound", direction = "inbound", remote = local.client_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr },
      { name = "storage-allow-storagesg-inbound", direction = "inbound", remote = local.storage_security_group },
      { name = "client-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" }
    ]
    ) : (local.enable_compute ?
    [
      { name = "client-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "client-allow-computesg-inbound", direction = "inbound", remote = local.compute_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr },
      { name = "client-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" }
    ]
    :
    [
      { name = "client-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr },
      { name = "storage-allow-storagesg-inbound", direction = "inbound", remote = local.storage_security_group },
      { name = "client-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" }
    ]
  )

  compute_security_group_rules = local.enable_client ? (local.enable_compute ? (local.enable_storage ?
    [
      { name = "compute-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "compute-allow-clientsg-inbound", direction = "inbound", remote = local.client_security_group },
      { name = "compute-allow-computesg-inbound", direction = "inbound", remote = local.compute_security_group },
      { name = "compute-allow-storagesg-inbound", direction = "inbound", remote = local.storage_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr },
      { name = "compute-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" }
    ] :
    [
      { name = "compute-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "compute-allow-clientsg-inbound", direction = "inbound", remote = local.client_security_group },
      { name = "compute-allow-computesg-inbound", direction = "inbound", remote = local.compute_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr },
      { name = "compute-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" },
    ]
    ) : (local.enable_storage ?
    [
      { name = "compute-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "compute-allow-clientsg-inbound", direction = "inbound", remote = local.client_security_group },
      { name = "compute-allow-storagesg-inbound", direction = "inbound", remote = local.storage_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr },
      { name = "compute-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" }
    ] :
    [
      { name = "compute-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "compute-allow-clientsg-inbound", direction = "inbound", remote = local.client_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr },
      { name = "compute-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" }
    ]
    )
    ) : (local.enable_compute ? (local.enable_storage ?
      [
        { name = "compute-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
        { name = "compute-allow-computesg-inbound", direction = "inbound", remote = local.compute_security_group },
        { name = "compute-allow-storagesg-inbound", direction = "inbound", remote = local.storage_security_group },
        { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr },
        { name = "compute-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" }
      ] :
      [
        { name = "compute-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
        { name = "compute-allow-computesg-inbound", direction = "inbound", remote = local.compute_security_group },
        { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr },
        { name = "compute-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" }
      ]
      ) : (local.enable_storage ?
      [
        { name = "compute-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
        { name = "compute-allow-storagesg-inbound", direction = "inbound", remote = local.storage_security_group },
        { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr },
        { name = "compute-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" }
      ] :
      [
        { name = "compute-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
        { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr },
        { name = "compute-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" }
      ]
    )
  )

  storage_security_group_rules = local.enable_compute ? (local.enable_storage ?
    [
      { name = "storage-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "storage-allow-computesg-inbound", direction = "inbound", remote = local.compute_security_group },
      { name = "storage-allow-storagesg-inbound", direction = "inbound", remote = local.storage_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr },
      { name = "client-allow-clientsg-inbound", direction = "inbound", remote = local.client_security_group },
      { name = "client-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" }
    ] :
    [
      { name = "storage-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "storage-allow-computesg-inbound", direction = "inbound", remote = local.compute_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr },
      { name = "client-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" },
      { name = "compute-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" }

    ]
    ) : (local.enable_storage ?
    [
      { name = "storage-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "storage-allow-storagesg-inbound", direction = "inbound", remote = local.storage_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr },
      { name = "client-allow-clientsg-inbound", direction = "inbound", remote = local.client_security_group },
      { name = "client-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" }
    ] :
    [
      { name = "storage-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr },
      { name = "client-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" },
      { name = "compute-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" }

    ]
  )

  storage_nfs_security_group_rules = [
    {
      name      = "allow-all-compute-sg"
      direction = "inbound"
      remote    = local.compute_security_group
    }
  ]

  bastion_security_group_update_rule = local.enable_compute ? [
    { name = "bastion-allow-compute-sg", direction = "inbound", remote = local.compute_security_group }
    ] : (local.enable_storage ? [
      { name = "bastion-allow-storage-sg", direction = "inbound", remote = local.storage_security_group }
      ] : (local.enable_client ? [
      { name = "bastion-allow-client-sg", direction = "inbound", remote = local.client_security_group }] : []
  ))
}

locals {
  storage_security_group_name_id = var.storage_security_group_name != null ? data.ibm_is_security_group.storage_security_group[*].id : []
  client_security_group_name_id  = var.client_security_group_name != null ? data.ibm_is_security_group.client_security_group[*].id : []
  gklm_security_group_name_id    = var.gklm_security_group_name != null ? data.ibm_is_security_group.gklm_security_group[*].id : []
  ldap_security_group_name_id    = var.ldap_security_group_name != null ? data.ibm_is_security_group.ldap_security_group[*].id : []
  compute_security_group_name_id = var.compute_security_group_name != null ? data.ibm_is_security_group.compute_security_group[*].id : []
}

locals {
  catalog_offering = {
    version_crn = "crn:v1:bluemix:public:globalcatalog-collection:global::1082e7d2-5e2f-0a11-a3bc-f88a8e1931fc:version:61e655c5-40b6-4b68-a6ab-e6c77a457fce-global/e08b9ca5-699c-4779-8369-1a0c1ed54b30-global"
    plan_crn    = "crn:v1:bluemix:public:globalcatalog-collection:global::1082e7d2-5e2f-0a11-a3bc-f88a8e1931fc:plan:sw.1082e7d2-5e2f-0a11-a3bc-f88a8e1931fc.d114e7ab-4f7e-40c4-98cc-f0c000cbf3a7-global"
  }
}
