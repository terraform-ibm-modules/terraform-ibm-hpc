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
    {
      name   = "management-rg",
      create = local.create_resource_group,
      use_prefix : false
    },
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

  client_instance_count         = sum(var.client_instances[*]["count"])
  management_instance_count     = sum(var.management_instances[*]["count"])
  static_compute_instance_count = sum(var.compute_instances[*]["count"])
  storage_instance_count        = sum(var.storage_instances[*]["count"])
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

  # Address Prefixes calculation
  address_prefixes = {
    for zone in local.zones : zone => contains(local.active_zones, zone) ? distinct(compact([
      local.client_instance_count != 0 && local.management_instance_count != 0 ? var.client_subnets_cidr[index(local.active_zones, zone)] : null,
      var.compute_subnets_cidr[index(local.active_zones, zone)],
      local.storage_instance_count != 0 ? var.storage_subnets_cidr[index(local.active_zones, zone)] : null,
      local.storage_instance_count != 0 && local.protocol_instance_count != 0 ? var.protocol_subnets_cidr[index(local.active_zones, zone)] : null,
      # bastion subnet and instance will always be in first active zone
      zone == local.active_zones[0] ? var.bastion_subnets_cidr[0] : null
    ])) : []
  }

  # Subnet calculation
  active_subnets = {
    for zone in local.zones : zone => contains(local.active_zones, zone) ? [
      local.client_instance_count != 0 && local.management_instance_count != 0 ? {
        name           = "client-subnet-${zone}"
        acl_name       = "hpc-acl"
        cidr           = var.client_subnets_cidr[index(local.active_zones, zone)]
        public_gateway = false
      } : null,
      {
        name           = "compute-subnet-${zone}"
        acl_name       = "hpc-acl"
        cidr           = var.compute_subnets_cidr[index(local.active_zones, zone)]
        public_gateway = true
      },
      local.storage_instance_count != 0 ? {
        name           = "storage-subnet-${zone}"
        acl_name       = "hpc-acl"
        cidr           = var.storage_subnets_cidr[index(local.active_zones, zone)]
        public_gateway = true
      } : null,
      local.storage_instance_count != 0 && local.protocol_instance_count != 0 ? {
        name           = "protocol-subnet-${zone}"
        acl_name       = "hpc-acl"
        cidr           = var.protocol_subnets_cidr[index(local.active_zones, zone)]
        public_gateway = false
      } : null,
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
  network_acl_inbound_rules = [
    for cidr_index in range(length(local.cidrs_network_acl_rules)) : {
      name        = format("allow-inbound-%s", cidr_index + 1)
      action      = "allow"
      destination = var.network_cidr
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
      source      = var.network_cidr
    }
  ]
  network_acl_rules = flatten([local.network_acl_inbound_rules, local.network_acl_outbound_rules])

  vpcs = var.vpc == null ? [
    {
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
      subnets             = local.subnets
      use_public_gateways = local.use_public_gateways
      address_prefixes    = local.address_prefixes
    }
  ] : []

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
    vpc_name                        = var.vpc == null ? local.name : var.vpc
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
      vpc_name       = var.vpc == null ? local.name : var.vpc
      subnet_name    = "bastion-subnet"
      mode           = "policy"
      resource_group = local.resource_group
      connections = [
        {
          peer_address  = var.vpn_peer_address
          preshared_key = var.vpn_preshared_key
          peer_cidrs    = var.vpn_peer_cidr
          local_cidrs   = var.bastion_subnets_cidr
        }
      ]
    }
  ] : []

  # Define transit gateway (to connect multiple VPC)
  enable_transit_gateway         = false
  transit_gateway_global         = false
  transit_gateway_resource_group = local.resource_group
  transit_gateway_connections    = [var.vpc]

  active_cos = [
    (
      var.enable_cos_integration || var.enable_vpc_flow_logs || var.enable_atracker
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
          kms_key       = var.key_management == "key_protect" ? format("%s-key", var.prefix) : null
        } : null,
        var.enable_vpc_flow_logs ? {
          name          = "vpc-flow-logs-bucket"
          storage_class = "standard"
          endpoint_type = "public"
          force_delete  = true
          kms_key       = var.key_management == "key_protect" ? format("%s-slz-key", var.prefix) : null
        } : null,
        var.enable_atracker ? {
          name          = "atracker-bucket"
          storage_class = "standard"
          endpoint_type = "public"
          force_delete  = true
          kms_key       = var.key_management == "key_protect" ? format("%s-atracker-key", var.prefix) : null
        } : null
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

  # Prerequisite: Existing key protect instance is not supported, always create a key management instance
  active_keys = [
    var.key_management != null ? {
      name = format("%s-vsi-key", var.prefix)
    } : null,
    var.enable_cos_integration ? {
      name = format("%s-key", var.prefix)
    } : null,
    var.enable_vpc_flow_logs ? {
      name = format("%s-slz-key", var.prefix)
    } : null,
    var.enable_atracker ? {
      name = format("%s-atracker-key", var.prefix)
    } : null
  ]
  key_management = {
    name           = var.key_management == "hs_crypto" ? var.hpcs_instance_name : format("%s-kms", var.prefix)
    resource_group = local.resource_group
    use_hs_crypto  = var.key_management == "hs_crypto" ? true : false
    keys           = [for each in local.active_keys : each if each != null]
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
      resource_group = local.resource_group
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
    resource_group        = local.resource_group
    receive_global_events = var.enable_atracker
    collector_bucket_name = "atracker-bucket"
    add_route             = var.enable_atracker
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
  skip_all_s2s_auth_policies             = false
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
    skip_all_s2s_auth_policies             = local.skip_all_s2s_auth_policies
  }
}
