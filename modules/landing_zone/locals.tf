locals {
  # Defined values
  name   = "lsf"
  prefix = var.prefix
  tags   = [local.prefix, local.name]

  # Derived values

  # Resource group calculation
  # If user defined then use existing else create new
  create_resource_group = var.existing_resource_group == "null" ? true : false
  resource_groups = var.existing_resource_group == "null" ? [
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
      name   = var.existing_resource_group,
      create = local.create_resource_group
    }
  ]
  # For the variables looking for resource group names only (transit_gateway, key_management, atracker)
  service_resource_group = var.existing_resource_group == "null" ? "${local.prefix}-service-rg" : var.existing_resource_group

  client_instance_count         = sum(var.client_instances[*]["count"])
  management_instance_count     = sum(var.management_instances[*]["count"])
  static_compute_instance_count = sum(var.compute_instances[*]["count"])
  storage_instance_count        = var.storage_type == "persistent" ? sum(var.storage_servers[*]["count"]) : sum(var.storage_instances[*]["count"])
  protocol_instance_count       = sum(var.protocol_instances[*]["count"])

  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))
  zones  = ["zone-1", "zone-2", "zone-3"]
  active_zones = [
    for zone in var.zones :
    format("zone-%d", substr(zone, -1, -2))
  ]
  # Future use
  #zone_count = length(local.active_zones)

  bastion_sg_variable_cidr_list = split(",", var.cluster_cidr)

  # Address Prefixes calculation
  address_prefixes = {
    "zone-${element(split("-", var.zones[0]), 2)}" = [local.bastion_sg_variable_cidr_list[0]]
  }

  # Subnet calculation
  active_subnets = {
    for zone in local.zones : zone => contains(local.active_zones, zone) ? [
      local.client_instance_count != 0 ? {
        name           = "client-subnet-${zone}"
        acl_name       = "hpc-acl"
        cidr           = var.client_subnets_cidr[index(local.active_zones, zone)]
        public_gateway = true
        no_addr_prefix = true
      } : null,
      {
        name           = "compute-subnet-${zone}"
        acl_name       = "hpc-acl"
        cidr           = var.vpc_cluster_private_subnets_cidr_blocks[index(local.active_zones, zone)]
        public_gateway = true
        no_addr_prefix = true
      },
      local.storage_instance_count != 0 ? {
        name           = "storage-subnet-${zone}"
        acl_name       = "hpc-acl"
        cidr           = var.storage_subnets_cidr[index(local.active_zones, zone)]
        public_gateway = true
        no_addr_prefix = true
      } : null,
      local.storage_instance_count != 0 && local.protocol_instance_count != 0 ? {
        name           = "protocol-subnet-${zone}"
        acl_name       = "hpc-acl"
        cidr           = var.protocol_subnets_cidr[index(local.active_zones, zone)]
        public_gateway = true
        no_addr_prefix = true
      } : null,
      zone == local.active_zones[0] ? {
        name           = "bastion-subnet"
        acl_name       = "hpc-acl"
        cidr           = var.vpc_cluster_login_private_subnets_cidr_blocks
        public_gateway = true
        no_addr_prefix = true
      } : null
    ] : []
  }
  subnets = { for zone, subnets in local.active_subnets : zone => [for each in subnets : each if each != null] }

  # Use public gateway calculation
  use_public_gateways = {
    for zone in local.zones : zone => contains(local.active_zones, zone) ? true : false
  }

  # VPC calculation
  # If user defined then use existing else create new
  # Calculate network acl rules (can be done inplace in vpcs)
  # TODO: VPN expectation
  cidrs_network_acl_rules = compact(flatten(["0.0.0.0/0"]))
  network_acl_inbound_rules = [
    for cidr_index in range(length(local.cidrs_network_acl_rules)) : {
      name        = format("allow-inbound-%s", cidr_index + 1)
      action      = "allow"
      destination = var.cluster_cidr
      direction   = "inbound"
      source      = element(local.cidrs_network_acl_rules, cidr_index)
    }
  ]
  network_acl_outbound_rules = [
    for cidr_index in range(length(local.cidrs_network_acl_rules)) : {
      name        = format("allow-outbound-%s", cidr_index + 1)
      action      = "allow"
      destination = element(local.cidrs_network_acl_rules, cidr_index)
      direction   = "outbound"
      source      = var.cluster_cidr
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
      existing_subnets = (var.vpc_name != null && length(var.compute_subnet_id) > 0) ? [
        {
          id             = var.compute_subnet_id
          public_gateway = false
        },
        {
          id             = var.bastion_subnet_id
          public_gateway = false
        }
      ] : null
      prefix                       = local.name
      resource_group               = var.existing_resource_group == "null" ? "${local.prefix}-workload-rg" : var.existing_resource_group
      clean_default_security_group = true
      clean_default_acl            = true
      flow_logs_bucket_name        = var.enable_vpc_flow_logs ? "vpc-flow-logs-bucket" : null
      network_acls = [
        {
          name              = "hpc-acl"
          add_cluster_rules = false
          rules             = local.network_acl_rules
        }
      ],
      subnets             = (var.vpc_name != null && length(var.compute_subnet_id) > 0) ? null : local.subnets
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

  vsi = []

  # Define VPN
  vpn_gateways = var.enable_vpn ? [
    {
      name           = "vpn-gw"
      vpc_name       = local.name
      subnet_name    = length(var.compute_subnet_id) == 0 ? "bastion-subnet" : data.ibm_is_subnet.subnet[0].name
      mode           = "policy"
      resource_group = local.service_resource_group
    }
  ] : []

  # Define transit gateway (to connect multiple VPC)
  enable_transit_gateway         = false
  transit_gateway_global         = false
  transit_gateway_resource_group = local.service_resource_group
  transit_gateway_connections    = [var.vpc_name]

  active_cos = [
    (
      var.enable_cos_integration || var.enable_vpc_flow_logs || var.enable_atracker || var.observability_logs_enable
      ) ? {
      name                          = var.cos_instance_name == null ? "hpc-cos" : var.cos_instance_name
      resource_group                = local.service_resource_group
      plan                          = "standard"
      random_suffix                 = true
      use_data                      = var.cos_instance_name == null ? false : true
      keys                          = []
      skip_flowlogs_s2s_auth_policy = var.skip_flowlogs_s2s_auth_policy
      skip_kms_s2s_auth_policy      = var.skip_kms_s2s_auth_policy

      # Extra bucket for solution specific object storage
      buckets = [
        var.enable_cos_integration ? {
          name          = "hpc-bucket"
          storage_class = "standard"
          endpoint_type = "public"
          force_delete  = true
          kms_key       = var.key_management == "key_protect" ? (var.kms_key_name == null ? format("%s-key", var.prefix) : var.kms_key_name) : null
          expire_rule   = null
        } : null,
        var.enable_vpc_flow_logs ? {
          name          = "vpc-flow-logs-bucket"
          storage_class = "standard"
          endpoint_type = "public"
          force_delete  = true
          kms_key       = var.key_management == "key_protect" ? (var.kms_key_name == null ? format("%s-slz-key", var.prefix) : var.kms_key_name) : null
          expire_rule = {
            days    = 30
            enable  = true
            rule_id = "bucket-expire-rule"
          }
        } : null,
        var.enable_atracker ? {
          name          = "atracker-bucket"
          storage_class = "standard"
          endpoint_type = "public"
          force_delete  = true
          kms_key       = var.key_management == "key_protect" ? (var.kms_key_name == null ? format("%s-atracker-key", var.prefix) : var.kms_key_name) : null
          expire_rule = {
            days    = 30
            enable  = true
            rule_id = "bucket-expire-rule"
          }
        } : null,
        var.observability_logs_enable ? {
          name          = "logs-data-bucket"
          storage_class = "standard"
          endpoint_type = "public"
          force_delete  = true
          kms_key       = var.key_management == "key_protect" ? (var.kms_key_name == null ? format("%s-logs-data-key", var.prefix) : var.kms_key_name) : null
          expire_rule = {
            days    = 30
            enable  = true
            rule_id = "bucket-expire-rule"
          }
        } : null,
        var.observability_logs_enable ? {
          name          = "metrics-data-bucket"
          storage_class = "standard"
          endpoint_type = "public"
          force_delete  = true
          kms_key       = var.key_management == "key_protect" ? (var.kms_key_name == null ? format("%s-metrics-data-key", var.prefix) : var.kms_key_name) : null
          expire_rule = {
            days    = 30
            enable  = true
            rule_id = "bucket-expire-rule"
          }
        } : null
      ]
    } : null
  ]

  cos = [
    for instance in local.active_cos :
    {
      name                          = instance.name
      resource_group                = instance.resource_group
      plan                          = instance.plan
      random_suffix                 = instance.random_suffix
      use_data                      = instance.use_data
      keys                          = instance.keys
      skip_flowlogs_s2s_auth_policy = instance.skip_flowlogs_s2s_auth_policy
      skip_kms_s2s_auth_policy      = instance.skip_kms_s2s_auth_policy
      buckets = [
        for bucket in instance.buckets :
        {
          name          = bucket.name
          storage_class = bucket.storage_class
          endpoint_type = bucket.endpoint_type
          force_delete  = bucket.force_delete
          kms_key       = bucket.kms_key
          expire_rule   = bucket.expire_rule
        }
        if bucket != null
      ]
    }
    if instance != null
  ]

  active_keys = var.key_management == "key_protect" ? (var.kms_key_name == null ? [
    var.key_management == "key_protect" ? {
      name = format("%s-vsi-key", var.prefix)
    } : null,
    var.enable_cos_integration ? {
      name = format("%s-key", var.prefix)
    } : null,
    var.enable_vpc_flow_logs ? {
      name = format("%s-slz-key", var.prefix)
    } : null,
    var.observability_logs_enable ? {
      name = format("%s-metrics-data-key", var.prefix)
    } : null,
    var.observability_logs_enable ? {
      name = format("%s-logs-data-key", var.prefix)
    } : null,
    var.enable_atracker ? {
      name = format("%s-atracker-key", var.prefix)
    } : null
    ] : [
    {
      name             = var.kms_key_name
      existing_key_crn = data.ibm_kms_key.kms_key[0].keys[0].crn
    }
  ]) : null

  key_management = var.key_management == "key_protect" ? {
    name           = var.kms_instance_name != null ? var.kms_instance_name : format("%s-kms", var.prefix) # var.key_management == "hs_crypto" ? var.hpcs_instance_name : format("%s-kms", var.prefix)
    resource_group = local.service_resource_group
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

  total_vsis = sum([
    local.management_instance_count,
    local.static_compute_instance_count,
    local.storage_instance_count,
    local.protocol_instance_count
  ]) * length(local.active_zones)
  placement_groups_count = var.placement_strategy == "host_spread" ? local.total_vsis / 12 : var.placement_strategy == "power_spread" ? local.total_vsis / 4 : 0
  vpc_placement_groups = [
    for placement_group in range(local.placement_groups_count) : {
      name           = format("%s", placement_group + 1)
      resource_group = local.service_resource_group
      strategy       = var.placement_strategy
    }
  ]

  # Variables to explore
  clusters = coalesce(var.clusters, [])

  # Unexplored variables
  security_groups           = []
  virtual_private_endpoints = []
  service_endpoints         = "private"
  atracker = {
    resource_group        = local.service_resource_group
    receive_global_events = var.enable_atracker
    collector_bucket_name = "atracker-bucket"
    add_route             = var.enable_atracker ? true : false
  }
  wait_till = "IngressReady"
  appid = {
    use_appid = false
  }
  teleport_vsi = []
  teleport_config_data = {
    domain = var.prefix
  }
  f5_vsi = []
  f5_template_data = {
    license_type = "none"
  }
  skip_kms_block_storage_s2s_auth_policy = true
}


# env variables (use to override)
locals {
  env = {
    resource_groups                        = local.resource_groups
    cluster_cidr                           = var.cluster_cidr
    vpcs                                   = local.vpcs
    vpn_gateways                           = local.vpn_gateways
    enable_transit_gateway                 = local.enable_transit_gateway
    transit_gateway_global                 = local.transit_gateway_global
    transit_gateway_resource_group         = local.transit_gateway_resource_group
    transit_gateway_connections            = local.transit_gateway_connections
    vsi                                    = local.vsi
    ssh_keys                               = local.ssh_keys
    cos                                    = local.cos
    key_management                         = local.key_management
    atracker                               = local.atracker
    vpc_placement_groups                   = local.vpc_placement_groups
    security_groups                        = local.security_groups
    virtual_private_endpoints              = local.virtual_private_endpoints
    service_endpoints                      = local.service_endpoints
    clusters                               = local.clusters
    wait_till                              = local.wait_till
    appid                                  = local.appid
    teleport_config_data                   = local.teleport_config_data
    teleport_vsi                           = local.teleport_vsi
    f5_vsi                                 = local.f5_vsi
    f5_template_data                       = local.f5_template_data
    skip_kms_block_storage_s2s_auth_policy = local.skip_kms_block_storage_s2s_auth_policy
  }
}
