locals {
  # Defined values
  name           = "hpc-packer"
  prefix         = var.prefix
  tags           = [local.prefix, local.name]
  no_addr_prefix = true
  # Derived values
  vpc_id = var.vpc_name == null ? module.landing_zone.vpc_data[0].vpc_id : data.ibm_is_vpc.existing_vpc[0].id
  # Resource group calculation
  # If user defined then use existing else create new
  create_resource_group = var.resource_group == "null" ? true : false
  resource_groups = var.resource_group == "null" ? [
    {
      name   = "${local.prefix}-service-rg",
      create = local.create_resource_group,
      use_prefix : false
    },
    {
      name   = "${local.prefix}-workload-rg",
      create = local.create_resource_group,
      use_prefix : false
    }
    ] : [
    {
      name   = var.resource_group,
      create = local.create_resource_group
    }
  ]
  # For the variables looking for resource group names only (transit_gateway, key_management, atracker)
  resource_group = var.resource_group == "null" ? "${local.prefix}-service-rg" : var.resource_group
  region         = join("-", slice(split("-", var.zones[0]), 0, 2))
  zones          = ["zone-1", "zone-2", "zone-3"]
  active_zones = [
    for zone in var.zones :
    format("zone-%d", substr(zone, -1, -2))
  ]
  packer_sg_variable_cidr_list = split(",", var.network_cidr)
  address_prefixes = {
    "zone-${element(split("-", var.zones[0]), 2)}" = [local.packer_sg_variable_cidr_list[0]]
  }

  # Subnet calculation
  active_subnets = {
    for zone in local.zones : zone => contains(local.active_zones, zone) ? [
      zone == local.active_zones[0] ? {
        name           = "subnet"
        acl_name       = "hpc-acl"
        cidr           = var.packer_subnet_cidr[0]
        public_gateway = true
        no_addr_prefix = local.no_addr_prefix
      } : null
    ] : []
  }
  subnets = { for zone, subnets in local.active_subnets : zone => [for each in subnets : each if each != null] }

  # Use public gateway calculation
  use_public_gateways = {
    for zone in local.zones : zone => contains(local.active_zones, zone) ? true : false
  }
  network_acl_inbound_rules = [
    {
      name        = "allow-all-inbound"
      action      = "allow"
      destination = "0.0.0.0/0"
      direction   = "inbound"
      source      = "0.0.0.0/0"
    }
  ]
  network_acl_outbound_rules = [
    {
      name        = "allow-all-outbound"
      action      = "allow"
      destination = "0.0.0.0/0"
      direction   = "outbound"
      source      = "0.0.0.0/0"
    }
  ]
  network_acl_rules = flatten([local.network_acl_inbound_rules, local.network_acl_outbound_rules])

  use_public_gateways_existing_vpc = {
    "zone-1" = false
    "zone-2" = false
    "zone-3" = false
  }

  vpcs = [
    {
      existing_vpc_id = var.vpc_name == null ? null : data.ibm_is_vpc.existing_vpc[0].id
      existing_subnets = (var.vpc_name != null && var.subnet_id != null) ? [
        {
          id             = var.subnet_id
          public_gateway = false
        }
      ] : null
      prefix                       = local.name
      resource_group               = var.resource_group == "null" ? "${local.prefix}-workload-rg" : var.resource_group
      clean_default_security_group = true
      clean_default_acl            = true
      #   flow_logs_bucket_name        = var.enable_vpc_flow_logs ? "vpc-flow-logs-bucket" : null
      network_acls = [
        {
          name              = "hpc-acl"
          add_cluster_rules = false
          rules             = local.network_acl_rules
        }
      ],
      subnets             = (var.vpc_name != null && var.subnet_id != null) ? null : local.subnets
      use_public_gateways = var.vpc_name == null ? local.use_public_gateways : local.use_public_gateways_existing_vpc
      address_prefixes    = var.vpc_name == null ? local.address_prefixes : null
    }
  ]

  # Define SSH key
  ssh_keys = [
    for item in var.ssh_keys : {
      name = item
    }
  ]

  security_groups            = []
  vpc_name                   = var.vpc_name == null ? module.landing_zone.vpc_data[0].vpc_name : var.vpc_name
  packer_node_name           = format("%s-%s", local.prefix, "packer")
  packer_machine_type        = "bx2-2x8"
  packer_image_id            = data.ibm_is_image.packer.id
  packer_ssh_keys            = [for name in var.ssh_keys : data.ibm_is_ssh_key.packer[name].id]
  kms_encryption_enabled     = var.key_management == "key_protect" ? true : false
  landing_zone_kms_output    = var.key_management == "key_protect" ? (var.kms_key_name == null ? module.landing_zone.key_map[format("%s-vsi-key", var.prefix)] : module.landing_zone.key_map[var.kms_key_name]) : null
  boot_volume_encryption_key = var.key_management == "key_protect" ? local.landing_zone_kms_output["crn"] : null
  existing_kms_instance_guid = var.key_management == "key_protect" ? module.landing_zone.key_management_guid : null
  landing_zone_subnet_output = [for subnet in flatten(module.landing_zone.subnet_data) : {
    name = subnet["name"]
    id   = subnet["id"]
    zone = subnet["zone"]
    cidr = subnet["cidr"]
    crn  = subnet["crn"]
    }
  ]
  existing_subnets = var.subnet_id != null ? [
    element(local.landing_zone_subnet_output, index([local.landing_zone_subnet_output[0].id], var.subnet_id))
  ] : []
  packer_subnets = var.subnet_id == null ? local.landing_zone_subnet_output : local.existing_subnets
  security_group = {
    name  = "${local.prefix}-hpc-packer-sg"
    rules = local.packer_security_group_rules
  }

  packer_vsi_data = flatten(module.packer_vsi["list"])
  # packer_vsi_id      = local.packer_vsi_data[0]["id"]
  packer_vsi_name    = local.packer_vsi_data[0]["name"]
  packer_floating_ip = var.enable_fip ? local.packer_vsi_data[0]["floating_ip"] : null

  packer_resource_groups = {
    service_rg  = var.resource_group == "null" ? module.landing_zone.resource_group_data["${var.prefix}-service-rg"] : one(values(module.landing_zone.resource_group_data))
    workload_rg = var.resource_group == "null" ? module.landing_zone.resource_group_data["${var.prefix}-workload-rg"] : one(values(module.landing_zone.resource_group_data))
  }

  vsi = []

  # Define VPN
  vpn_gateways = var.enable_vpn ? [
    {
      name           = "packer-vpn-gw"
      vpc_name       = local.name
      subnet_name    = (var.vpc_name != null && var.subnet_id != null) ? data.ibm_is_subnet.existing_subnet[0].name : "subnet"
      mode           = "policy"
      resource_group = var.resource_group == "null" ? "${local.prefix}-service-rg" : var.resource_group
    }
  ] : []

  # Define transit gateway (to connect multiple VPC)
  enable_transit_gateway         = false
  transit_gateway_resource_group = local.resource_group
  transit_gateway_connections    = [var.vpc_name]

  cos = []

  active_keys = var.key_management == "key_protect" ? (var.kms_key_name == null ? [
    var.key_management == "key_protect" ? {
      name = format("%s-vsi-key", var.prefix)
    } : null
    ] : [
    {
      name             = var.kms_key_name
      existing_key_crn = data.ibm_kms_key.kms_key[0].keys[0].crn
    }
  ]) : null
  key_management = var.key_management == "key_protect" ? {
    name           = var.kms_instance_name != null ? var.kms_instance_name : format("%s-kms", var.prefix)
    resource_group = local.resource_group
    use_hs_crypto  = false
    keys           = [for each in local.active_keys : each if each != null]
    use_data       = var.kms_instance_name != null ? true : false
    } : {
    name           = null
    resource_group = null
    use_hs_crypto  = null
    keys           = []
    use_data       = null
  }
  # Unexplored variables

  virtual_private_endpoints = []
  service_endpoints         = "private"
  atracker = {
    resource_group        = local.resource_group
    receive_global_events = false
    collector_bucket_name = "atracker-bucket"
    add_route             = false
  }
  secrets_manager = {
    use_secrets_manager = false
  }
  access_groups = []
  f5_vsi        = []
  #add_kms_block_storage_s2s = false
  skip_kms_block_storage_s2s_auth_policy = true
  clusters                               = []
  wait_till                              = "IngressReady"
  teleport_vsi                           = []
  iam_account_settings = {
    enable = false
  }
  teleport_config_data = {
    domain = var.prefix
  }
  f5_template_data = {
    license_type = "none"
  }
  appid = {
    use_appid = false
  }
}

####################################################
# The code below does some internal processing of variables and locals
# (e.g. concatenating lists).

locals {
  # (overridable) switch to enable extra outputs (debugging)
  # print_extra_outputs = false

  # (overridable) switch to add the current (plan execution) IP to allowed CIDR list
  # add_current_ip_to_allowed_cidr = false

  # (overridable) list of extra entries for allowed CIDR list
  remote_allowed_ips_extra = []
}

locals {
  allowed_cidr = concat(var.remote_allowed_ips, local.remote_allowed_ips_extra, [])

  rhel_subscription_cidrs = [
    "161.26.0.0/16",
    "166.8.0.0/14"
  ]

  packer_sg_variable_cidr = flatten([
    # local.schematics_reserved_cidrs,
    local.allowed_cidr
    # var.network_cidr
  ])

  packer_security_group_rules = flatten([
    {
      name      = "allow-all-outbound-outbound"
      direction = "outbound"
      source    = "0.0.0.0/0"
    },
    [for cidr in local.packer_sg_variable_cidr : {
      name      = format("allow-variable-inbound-%s", index(local.packer_sg_variable_cidr, cidr) + 1)
      direction = "inbound"
      source    = cidr
      # ssh port
      tcp = {
        port_min = 22
        port_max = 22
      }
    }],
    [for cidr in local.packer_sg_variable_cidr : {
      name      = format("allow-variable-outbound-%s", index(local.packer_sg_variable_cidr, cidr) + 1)
      direction = "outbound"
      source    = cidr
    }],
    [for cidr in local.packer_sg_variable_cidr_list : {
      name      = format("allow-variable-inbound-cidr-%s", index(local.packer_sg_variable_cidr_list, cidr) + 1)
      direction = "inbound"
      source    = cidr
      tcp = {
        port_min = 22
        port_max = 22
      }
    }],
    [for cidr in local.packer_sg_variable_cidr_list : {
      name      = format("allow-variable-outbound-cidr-%s", index(local.packer_sg_variable_cidr_list, cidr) + 1)
      direction = "outbound"
      source    = cidr
    }],
    [for cidr in local.rhel_subscription_cidrs : {
      name      = format("allow-variable-outbound-cidr-rhel-%s", index(local.rhel_subscription_cidrs, cidr) + 1)
      direction = "outbound"
      source    = cidr
    }],
    [for cidr in local.rhel_subscription_cidrs : {
      name      = format("allow-variable-inbound-cidr-rhel-%s", index(local.rhel_subscription_cidrs, cidr) + 1)
      direction = "inbound"
      source    = cidr
    }]
  ])
}

# env variables (use to override)
locals {
  env = {
    resource_groups                        = local.resource_groups
    network_cidr                           = var.network_cidr
    vpcs                                   = local.vpcs
    vpn_gateways                           = local.vpn_gateways
    enable_transit_gateway                 = local.enable_transit_gateway
    transit_gateway_resource_group         = local.transit_gateway_resource_group
    transit_gateway_connections            = local.transit_gateway_connections
    vsi                                    = local.vsi
    ssh_keys                               = local.ssh_keys
    cos                                    = local.cos
    key_management                         = local.key_management
    atracker                               = local.atracker
    security_groups                        = local.security_groups
    virtual_private_endpoints              = local.virtual_private_endpoints
    service_endpoints                      = local.service_endpoints
    skip_kms_block_storage_s2s_auth_policy = local.skip_kms_block_storage_s2s_auth_policy
    clusters                               = local.clusters
    wait_till                              = local.wait_till
    iam_account_settings                   = local.iam_account_settings
    access_groups                          = local.access_groups
    f5_vsi                                 = local.f5_vsi
    f5_template_data                       = local.f5_template_data
    appid                                  = local.appid
    teleport_config_data                   = local.teleport_config_data
    teleport_vsi                           = local.teleport_vsi
    secrets_manager                        = local.secrets_manager
  }
}
