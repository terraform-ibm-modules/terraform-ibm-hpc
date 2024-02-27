locals {
  # Defined values
  name   = "hpc"
  prefix = var.prefix
  tags   = [local.prefix, local.name]
  schematics_reserved_cidrs = [
    "169.44.0.0/14",
    "169.60.0.0/14",
    "158.175.0.0/16",
    "158.176.0.0/15",
    "141.125.0.0/16",
    "161.156.0.0/16",
    "149.81.0.0/16",
    "159.122.111.224/27",
    "150.238.230.128/27",
    "169.55.82.128/27"
  ]

  # Derived values

  # Resource group calculation
  # If user defined then use existing else create new
  create_resource_group = var.resource_group == null ? true : false
  resource_groups = var.resource_group == null ? [
    {
      name   = "service-rg",
      create = local.create_resource_group,
      use_prefix : false
    },
    # {
    #   name   = "management-rg",
    #   create = local.create_resource_group,
    #   use_prefix : false
    # },
    {
      name   = "workload-rg",
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
  resource_group = var.resource_group == null ? "service-rg" : var.resource_group

  # login_instance_count          = sum(var.login_instances[*]["count"])
  # management_instance_count     = sum(var.management_instances[*]["count"])
  # static_compute_instance_count = sum(var.compute_instances[*]["count"])
  # storage_instance_count        = sum(var.storage_instances[*]["count"])
  # protocol_instance_count       = sum(var.protocol_instances[*]["count"])
  management_instance_count = var.management_node_count
  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))
  zones  = ["zone-1", "zone-2", "zone-3"]
  active_zones = [
    for zone in var.zones :
    format("zone-%d", substr(zone, -1, -2))
  ]
  # Future use
  #zone_count = length(local.active_zones)

  # Address Prefixes calculation
  # address_prefixes = {
  #   for zone in local.zones : zone => contains(local.active_zones, zone) ? distinct(compact([
  #     # local.login_instance_count != 0 && local.management_instance_count != 0 ? var.login_subnets_cidr[index(local.active_zones, zone)] : null,
  #     var.compute_subnets_cidr[index(local.active_zones, zone)],
  #     # local.storage_instance_count != 0 ? var.storage_subnets_cidr[index(local.active_zones, zone)] : null,
  #     # local.storage_instance_count != 0 && local.protocol_instance_count != 0 ? var.protocol_subnets_cidr[index(local.active_zones, zone)] : null,
  #     # bastion subnet and instance will always be in first active zone
  #     zone == local.active_zones[0] ? var.bastion_subnets_cidr[0] : null
  #   ])) : []
  # }
  bastion_sg_variable_cidr_list = split(",", var.network_cidr)
  address_prefixes = {
    "zone-${element(split("-", var.zones[0]), 2)}" = [local.bastion_sg_variable_cidr_list[0]]
    "zone-${element(split("-", var.zones[1]), 2)}" = [local.bastion_sg_variable_cidr_list[1]]
  }

  # Subnet calculation
  active_subnets = {
    for zone in local.zones : zone => contains(local.active_zones, zone) ? [
      # local.login_instance_count != 0 && local.management_instance_count != 0 ? {
      #   name           = "login-subnet-${zone}"
      #   acl_name       = "hpc-acl"
      #   cidr           = var.login_subnets_cidr[index(local.active_zones, zone)]
      #   public_gateway = false
      # } : null,
      {
        name           = "compute-subnet-${zone}"
        acl_name       = "hpc-acl"
        cidr           = var.compute_subnets_cidr[index(local.active_zones, zone)]
        public_gateway = var.vpc == "null" ? true : false
      },
      # local.storage_instance_count != 0 ? {
      #   name           = "storage-subnet-${zone}"
      #   acl_name       = "hpc-acl"
      #   cidr           = var.storage_subnets_cidr[index(local.active_zones, zone)]
      #   public_gateway = true
      # } : null,
      # local.storage_instance_count != 0 && local.protocol_instance_count != 0 ? {
      #   name           = "protocol-subnet-${zone}"
      #   acl_name       = "hpc-acl"
      #   cidr           = var.protocol_subnets_cidr[index(local.active_zones, zone)]
      #   public_gateway = false
      # } : null,
      zone == local.active_zones[0] ? {
        name           = "bastion-subnet"
        acl_name       = "hpc-acl"
        cidr           = var.bastion_subnets_cidr[0]
        public_gateway = false
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
  cidrs_network_acl_rules = compact(flatten([local.schematics_reserved_cidrs, var.allowed_cidr, var.network_cidr, "161.26.0.0/16", "166.8.0.0/14"]))
  #  network_acl_inbound_rules = [
  #    for cidr_index in range(length(local.cidrs_network_acl_rules)) : {
  #      name        = format("allow-inbound-%s", cidr_index + 1)
  #      action      = "allow"
  #      destination = var.network_cidr
  #      direction   = "inbound"
  #      source      = element(local.cidrs_network_acl_rules, cidr_index)
  #    }
  #  ]
  #  network_acl_outbound_rules = [
  #    for cidr_index in range(length(local.cidrs_network_acl_rules)) : {
  #      name        = format("allow-outbound-%s", cidr_index + 1)
  #      action      = "allow"
  #      destination = element(local.cidrs_network_acl_rules, cidr_index)
  #      direction   = "outbound"
  #      source      = var.network_cidr
  #    }
  #  ]
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

  # zone_1_managed_by_us = try(module.landing_zone[*].vpc_data[0].public_gateways, null)
  # zone_2_managed_by_us = try(module.landing_zone[*].vpc_data[0].public_gateways, null)
  # zone_3_managed_by_us = try(module.landing_zone[*].vpc_data[0].public_gateways, null)

  # use_public_gateways_existing_subnet = length(var.subnet_id) == 0 ? null : {
  #       "zone-1" = contains(keys(local.subnet_info), "${local.region}-1") ? local.subnet_info["${local.region}-1"] : false
  #       "zone-2" = contains(keys(local.subnet_info), "${local.region}-2") ? local.subnet_info["${local.region}-2"] : false
  #       "zone-3" = contains(keys(local.subnet_info), "${local.region}-3") ? local.subnet_info["${local.region}-3"] : false
  #     }

  use_public_gateways_existing_vpc = {
    "zone-1" = false
    "zone-2" = false
    "zone-3" = false
  }

  vpcs = [
    {
      existing_vpc_id = var.vpc == "null" ? null : data.ibm_is_vpc.itself[0].id
      existing_subnets = (var.vpc != "null" && length(var.subnet_id) > 0) ? [
        {
          id             = var.subnet_id[0]
          public_gateway = false
          # public_gateway = data.ibm_is_subnet.subnet[0].public_gateway != "" ? false : true
        },
        {
          id             = var.subnet_id[1]
          public_gateway = false
          # public_gateway = data.ibm_is_subnet.subnet[1].public_gateway != "" ? false : true
        },
        {
          id             = var.login_subnet_id
          public_gateway = false
          # public_gateway = data.ibm_is_subnet.subnet[1].public_gateway != "" ? false : true
        }
      ] : null
      prefix                       = local.name
      resource_group               = var.resource_group == null ? "workload-rg" : var.resource_group
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
      subnets             = (var.vpc != "null" && length(var.subnet_id) > 0) ? null : local.subnets
      use_public_gateways = var.vpc == "null" ? local.use_public_gateways : local.use_public_gateways_existing_vpc
      address_prefixes    = var.vpc == "null" ? local.address_prefixes : null
    }
  ]

  # Define SSH key
  ssh_keys = [
    for item in var.ssh_keys : {
      name = item
    }
  ]
  #bastion_ssh_keys = var.bastion_ssh_keys

  # Sample to spin VSI
  /*
  bastion_vsi = {
    name                            = "bastion-vsi"
    resource_group                  = var.resource_group == null ? "management-rg" : var.resource_group
    image_name                      = "ibm-ubuntu-22-04-1-minimal-amd64-4"
    machine_type                    = "cx2-4x8"
    vpc_name                        = var.vpc == "null" ? local.name : var.vpc
    subnet_names                    = ["bastion-subnet"]
    ssh_keys                        = local.bastion_ssh_keys
    vsi_per_subnet                  = 1
    user_data                       = var.enable_bastion ? data.template_file.bastion_user_data.rendered : null
    enable_floating_ip              = true
    boot_volume_encryption_key_name = var.key_management == null ? null : format("%s-vsi-key", var.prefix)
    security_group = {
      name = "bastion-sg"
      rules = flatten([
        {
          name      = "allow-ibm-inbound"
          direction = "inbound"
          source    = "161.26.0.0/16"
        },
        {
          name      = "allow-vpc-inbound"
          direction = "inbound"
          source    = var.network_cidr
        },
        [for cidr_index in range(length(flatten([local.schematics_reserved_cidrs, var.allowed_cidr]))) : {
          name      = format("allow-variable-inbound-%s", cidr_index + 1)
          direction = "inbound"
          source    = element(var.allowed_cidr, cidr_index)
          # ssh port
          tcp = {
            port_min = 22
            port_max = 22
          }
        }],
        {
          name      = "allow-ibm-http-outbound"
          direction = "outbound"
          source    = "161.26.0.0/16"
          tcp = {
            port_min = 80
            port_max = 80
          }
        },
        {
          name      = "allow-ibm-https-outbound"
          direction = "outbound"
          source    = "161.26.0.0/16"
          tcp = {
            port_min = 443
            port_max = 443
          }
        },
        {
          name      = "allow-ibm-dns-outbound"
          direction = "outbound"
          source    = "161.26.0.0/16"
          tcp = {
            port_min = 53
            port_max = 53
          }
        },
        {
          name      = "allow-vpc-outbound"
          direction = "outbound"
          source    = var.network_cidr
        },
        [for cidr_index in range(length(flatten([local.schematics_reserved_cidrs, var.allowed_cidr]))) : {
          name      = format("allow-variable-outbound-%s", cidr_index + 1)
          direction = "outbound"
          source    = element(var.allowed_cidr, cidr_index)
        }]
      ])
    }
  }
  vsi = [local.bastion_vsi]
  */
  vsi = []

  # Define VPN
  vpn_gateways = var.enable_vpn ? [
    {
      name           = "vpn-gw"
      vpc_name       = local.name
      subnet_name    = length(var.subnet_id) == 0 ? "bastion-subnet" : data.ibm_is_subnet.subnet[0].name
      mode           = "policy"
      resource_group = local.resource_group
      # connections = [
      #   {
      #     peer_address  = var.vpn_peer_address
      #     preshared_key = var.vpn_preshared_key
      #     peer_cidrs    = var.vpn_peer_cidr
      #     local_cidrs   = var.bastion_subnets_cidr
      #   }
      # ]
    }
  ] : []

  # Define transit gateway (to connect multiple VPC)
  enable_transit_gateway         = false
  transit_gateway_resource_group = local.resource_group
  transit_gateway_connections    = [var.vpc]

  active_cos = [
    (
      var.enable_cos_integration || var.enable_vpc_flow_logs
      ) ? {
      name           = var.cos_instance_name == null ? "hpc-cos" : var.cos_instance_name
      resource_group = local.resource_group
      plan           = "standard"
      random_suffix  = true
      use_data       = var.cos_instance_name == null ? false : true
      keys           = []

      # Extra bucket for solution specific object storage
      buckets = [
        var.enable_cos_integration ? {
          name          = "hpc-bucket"
          storage_class = "standard"
          endpoint_type = "public"
          force_delete  = true
          kms_key       = var.key_management == "key_protect" ? (var.kms_key_name == "null" ? format("%s-key", var.prefix) : var.kms_key_name) : null
        } : null,
        var.enable_vpc_flow_logs ? {
          name          = "vpc-flow-logs-bucket"
          storage_class = "standard"
          endpoint_type = "public"
          force_delete  = true
          kms_key       = var.key_management == "key_protect" ? (var.kms_key_name == "null" ? format("%s-slz-key", var.prefix) : var.kms_key_name) : null
        } : null
        # var.enable_atracker ? {
        #   name          = "atracker-bucket"
        #   storage_class = "standard"
        #   endpoint_type = "public"
        #   force_delete  = true
        #   kms_key       = var.key_management == "key_protect" ? (var.kms_key_name == "null" ? format("%s-atracker-key", var.prefix) : var.kms_key_name) : null
        # } : null
      ]
    } : null
  ]

  cos = [
    for instance in local.active_cos :
    {
      name           = instance.name
      resource_group = instance.resource_group
      plan           = instance.plan
      random_suffix  = instance.random_suffix
      use_data       = instance.use_data
      keys           = instance.keys
      buckets = [
        for bucket in instance.buckets :
        {
          name          = bucket.name
          storage_class = bucket.storage_class
          endpoint_type = bucket.endpoint_type
          force_delete  = bucket.force_delete
          kms_key       = bucket.kms_key
        }
        if bucket != null
      ]
    }
    if instance != null
  ]

  active_keys = var.key_management == "key_protect" ? (var.kms_key_name == "null" ? [
    var.key_management == "key_protect" ? {
      name = format("%s-vsi-key", var.prefix)
    } : null,
    var.enable_cos_integration ? {
      name = format("%s-key", var.prefix)
    } : null,
    var.enable_vpc_flow_logs ? {
      name = format("%s-slz-key", var.prefix)
    } : null
    # var.enable_atracker ? {
    #   name = format("%s-atracker-key", var.prefix)
    # } : null
    ] : [
    {
      name             = var.kms_key_name
      existing_key_crn = data.ibm_kms_key.kms_key[0].keys[0].crn
    }
  ]) : null
  key_management = var.key_management == "key_protect" ? {
    name           = var.kms_instance_name != "null" ? var.kms_instance_name : format("%s-kms", var.prefix) // var.key_management == "hs_crypto" ? var.hpcs_instance_name : format("%s-kms", var.prefix)
    resource_group = local.resource_group
    use_hs_crypto  = false
    keys           = [for each in local.active_keys : each if each != null]
    use_data       = var.kms_instance_name != "null" ? true : false
    } : {
    name           = null
    resource_group = null
    use_hs_crypto  = null
    keys           = []
    use_data       = null
  }

  total_vsis = sum([
    local.management_instance_count,
    # local.static_compute_instance_count,
    # local.storage_instance_count,
    # local.protocol_instance_count
  ]) * length(local.active_zones)
  # placement_groups_count = var.placement_strategy == "host_spread" ? local.total_vsis / 12 : var.placement_strategy == "power_spread" ? local.total_vsis / 4 : 0
  # vpc_placement_groups = [
  #   for placement_group in range(local.placement_groups_count) : {
  #     name           = format("%s", placement_group + 1)
  #     resource_group = local.resource_group
  #     strategy       = var.placement_strategy
  #   }
  # ]

  # Unexplored variables
  security_groups           = []
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
  access_groups             = []
  f5_vsi                    = []
  add_kms_block_storage_s2s = false
  clusters                  = []
  wait_till                 = "IngressReady"
  teleport_vsi              = []
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
    resource_groups                = local.resource_groups
    network_cidr                   = var.network_cidr
    vpcs                           = local.vpcs
    vpn_gateways                   = local.vpn_gateways
    enable_transit_gateway         = local.enable_transit_gateway
    transit_gateway_resource_group = local.transit_gateway_resource_group
    transit_gateway_connections    = local.transit_gateway_connections
    vsi                            = local.vsi
    ssh_keys                       = local.ssh_keys
    cos                            = local.cos
    key_management                 = local.key_management
    atracker                       = local.atracker
    # vpc_placement_groups           = local.vpc_placement_groups
    security_groups           = local.security_groups
    virtual_private_endpoints = local.virtual_private_endpoints
    service_endpoints         = local.service_endpoints
    add_kms_block_storage_s2s = local.add_kms_block_storage_s2s
    clusters                  = local.clusters
    wait_till                 = local.wait_till
    iam_account_settings      = local.iam_account_settings
    access_groups             = local.access_groups
    f5_vsi                    = local.f5_vsi
    f5_template_data          = local.f5_template_data
    appid                     = local.appid
    teleport_config_data      = local.teleport_config_data
    teleport_vsi              = local.teleport_vsi
    secrets_manager           = local.secrets_manager
  }
}
