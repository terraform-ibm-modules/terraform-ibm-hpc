locals {
  # Defined values
  name   = "hpc"
  prefix = var.prefix
  tags   = [local.prefix, local.name]
  # schematics_reserved_cidrs = [
  #   "169.44.0.0/14",
  #   "169.60.0.0/14",
  #   "158.175.0.0/16",
  #   "158.176.0.0/15",
  #   "141.125.0.0/16",
  #   "161.156.0.0/16",
  #   "149.81.0.0/16",
  #   "159.122.111.224/27",
  #   "150.238.230.128/27",
  #   "169.55.82.128/27"
  # ]

  # Derived values

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
  bastion_sg_variable_cidr_list = split(",", var.network_cidr)
  address_prefixes = {
    "zone-${element(split("-", var.zones[0]), 2)}" = [local.bastion_sg_variable_cidr_list[0]]
  }

  # Subnet calculation
  active_subnets = {
    for zone in local.zones : zone => contains(local.active_zones, zone) ? [
      {
        name           = "compute-subnet-${zone}"
        acl_name       = "hpc-acl"
        cidr           = var.compute_subnets_cidr[index(local.active_zones, zone)]
        public_gateway = var.vpc == null ? true : false
        no_addr_prefix = var.no_addr_prefix

      },
      zone == local.active_zones[0] ? {
        name           = "bastion-subnet"
        acl_name       = "hpc-acl"
        cidr           = var.bastion_subnets_cidr[0]
        public_gateway = false
        no_addr_prefix = var.no_addr_prefix
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
      name        = "test-1"
      action      = "allow"
      destination = "0.0.0.0/0"
      direction   = "inbound"
      source      = "0.0.0.0/0"
    }
  ]
  network_acl_outbound_rules = [
    {
      name        = "test-2"
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
      existing_vpc_id = var.vpc == null ? null : data.ibm_is_vpc.itself[0].id
      existing_subnets = (var.vpc != null && length(var.subnet_id) > 0) ? [
        {
          id             = var.subnet_id[0]
          public_gateway = false
        },
        {
          id             = var.login_subnet_id
          public_gateway = false
        }
      ] : null
      prefix                       = local.name
      resource_group               = var.resource_group == "null" ? "${local.prefix}-workload-rg" : var.resource_group
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
      subnets             = (var.vpc != null && length(var.subnet_id) > 0) ? null : local.subnets
      use_public_gateways = var.vpc == null ? local.use_public_gateways : local.use_public_gateways_existing_vpc
      address_prefixes    = var.vpc == null ? local.address_prefixes : null
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
      subnet_name    = length(var.subnet_id) == 0 ? "bastion-subnet" : data.ibm_is_subnet.subnet[0].name
      mode           = "policy"
      resource_group = local.resource_group
    }
  ] : []

  # Define transit gateway (to connect multiple VPC)
  enable_transit_gateway         = false
  transit_gateway_resource_group = local.resource_group
  transit_gateway_connections    = [var.vpc]

  active_cos = [
    (
      var.enable_cos_integration || var.enable_vpc_flow_logs || var.enable_atracker || var.scc_enable || var.observability_logs_enable
      ) ? {
      name                          = var.cos_instance_name == null ? "hpc-cos" : var.cos_instance_name
      resource_group                = local.resource_group
      plan                          = "standard"
      random_suffix                 = true
      use_data                      = var.cos_instance_name == null ? false : true
      keys                          = []
      skip_flowlogs_s2s_auth_policy = var.skip_flowlogs_s2s_auth_policy

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
            days    = var.cos_expiration_days
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
            days    = var.cos_expiration_days
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
            days    = var.cos_expiration_days
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
            days    = var.cos_expiration_days
            enable  = true
            rule_id = "bucket-expire-rule"
          }
        } : null,
        var.scc_enable ? {
          name          = "scc-bucket"
          storage_class = "standard"
          endpoint_type = "public"
          force_delete  = true
          kms_key       = var.key_management == "key_protect" ? (var.kms_key_name == null ? format("%s-scc-key", var.prefix) : var.kms_key_name) : null
          expire_rule = {
            days    = var.cos_expiration_days
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
    } : null,
    var.scc_enable ? {
      name = format("%s-scc-key", var.prefix)
    } : null
    ] : [
    {
      name             = var.kms_key_name
      existing_key_crn = data.ibm_kms_key.kms_key[0].keys[0].crn
    }
  ]) : null
  key_management = var.key_management == "key_protect" ? {
    name           = var.kms_instance_name != null ? var.kms_instance_name : format("%s-kms", var.prefix) # var.key_management == "hs_crypto" ? var.hpcs_instance_name : format("%s-kms", var.prefix)
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
  security_groups           = []
  virtual_private_endpoints = []
  service_endpoints         = "private"
  atracker = {
    resource_group        = local.resource_group
    receive_global_events = false
    collector_bucket_name = "atracker-bucket"
    add_route             = var.enable_atracker ? true : false
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


# env variables (use to override)
locals {
  env = {
    #ibmcloud_api_key              = var.ibmcloud_api_key
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
