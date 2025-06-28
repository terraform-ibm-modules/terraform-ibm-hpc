# define variables
locals {
  # Future use
  # products       = "scale"
  name           = "lsf"
  prefix         = var.prefix
  tags           = [local.prefix, local.name]
  vsi_interfaces = ["eth0", "eth1"]
  bms_interfaces = ["ens1", "ens2"]
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

  enable_client     = local.client_instance_count > 0
  enable_management = local.management_instance_count > 0
  enable_compute    = local.management_instance_count > 0 || local.static_compute_instance_count > 0
  enable_storage    = local.storage_instance_count > 0
  enable_protocol   = local.storage_instance_count > 0 && local.protocol_instance_count > 0
  # TODO: Fix the logic
  enable_block_storage = var.storage_type == "scratch" ? true : false

  # Future use
  # TODO: Fix the logic
  # enable_load_balancer = false

  client_node_name             = format("%s-%s", local.prefix, "client")
  management_node_name         = format("%s-%s", local.prefix, "mgmt")
  compute_node_name            = format("%s-%s", local.prefix, "comp")
  storage_node_name            = format("%s-%s", local.prefix, "strg")
  protocol_node_name           = format("%s-%s", local.prefix, "proto")
  storage_management_node_name = format("%s-%s", local.prefix, "strg-mgmt")
  ldap_node_name               = format("%s-%s", local.prefix, "ldap")
  afm_node_name                = format("%s-%s", local.prefix, "afm")
  gklm_node_name               = format("%s-%s", local.prefix, "gklm")
  cpmoute_management_node_name = format("%s-%s", local.prefix, "comp-mgmt")
  login_node_name              = format("%s-%s", local.prefix, "login")

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

  client_image_id   = data.ibm_is_image.client[*].id
  storage_image_id  = data.ibm_is_image.storage[*].id
  protocol_image_id = data.ibm_is_image.storage[*].id
  ldap_image_id     = data.ibm_is_image.ldap_vsi_image[*].id
  afm_image_id      = data.ibm_is_image.afm[*].id
  gklm_image_id     = data.ibm_is_image.gklm[*].id

  ssh_keys      = [for name in var.ssh_keys : data.ibm_is_ssh_key.ssh_keys[name].id]
  ldap_ssh_keys = [for name in var.ldap_instance_key_pair : data.ibm_is_ssh_key.ldap[name].id]
  gklm_ssh_keys = [for name in var.gklm_instance_key_pair : data.ibm_is_ssh_key.gklm[name].id]

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
  cluster_subnet_id = var.cluster_subnet_id
  storage_subnets   = var.storage_subnets
  protocol_subnets  = var.protocol_subnets

  compute_public_key_content  = one(module.compute_key[*].public_key_content)
  compute_private_key_content = one(module.compute_key[*].private_key_content)

  # Security Groups
  protocol_secondary_security_group = flatten([
    for subnet_index, subnet in local.protocol_subnets : [
      for i in range(var.protocol_instances[subnet_index]["count"]) : {
        security_group_id = one(module.storage_sg[*].security_group_id)
        interface_name    = "${subnet["name"]}-${i}"
      }
    ]
  ])

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
  client_security_group  = local.enable_client ? module.client_sg[0].security_group_id_for_ref : null
  compute_security_group = local.enable_compute ? module.compute_sg[0].security_group_id_for_ref : null
  storage_security_group = local.enable_storage ? module.storage_sg[0].security_group_id_for_ref : null

  client_security_group_rules = local.enable_client ? (local.enable_compute ?
    [
      { name = "client-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "client-allow-clientsg-inbound", direction = "inbound", remote = local.client_security_group },
      { name = "client-allow-computesg-inbound", direction = "inbound", remote = local.compute_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr }
    ] :
    [
      { name = "client-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "client-allow-clientsg-inbound", direction = "inbound", remote = local.client_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr }
    ]
    ) : (local.enable_compute ?
    [
      { name = "client-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "client-allow-computesg-inbound", direction = "inbound", remote = local.compute_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr }
    ]
    :
    [
      { name = "client-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr }
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
      { name = "compute-allow-all-outbound", direction = "outbound", remote = "0.0.0.0/0" }
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
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr }
    ] :
    [
      { name = "storage-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "storage-allow-computesg-inbound", direction = "inbound", remote = local.compute_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr }
    ]
    ) : (local.enable_storage ?
    [
      { name = "storage-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "storage-allow-storagesg-inbound", direction = "inbound", remote = local.storage_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr }
    ] :
    [
      { name = "storage-allow-bastionsg-inbound", direction = "inbound", remote = local.bastion_security_group },
      { name = "client-allow-network-inbound", direction = "inbound", remote = var.cluster_cidr }
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
