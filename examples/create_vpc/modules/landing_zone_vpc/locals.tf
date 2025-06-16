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
  security_group_name = format("%s-sg", local.prefix)

  # Resource group calculation
  # If user defined then use existing else create new
  create_resource_group = var.existing_resource_group == null ? true : false
  resource_group_id     = var.existing_resource_group != null ? data.ibm_resource_group.existing_resource_group.id : ""
  new_resource_groups = var.existing_resource_group == null ? [
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
      name   = var.existing_resource_group,
      create = local.create_resource_group
    }
  ]
  # For the variables looking for resource group names only (transit_gateway, key_management, atracker)
  existing_service_resource_group = var.existing_resource_group == null ? "service-rg" : var.existing_resource_group

  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))
  zones  = ["zone-1", "zone-2", "zone-3"]
  active_zones = [
    for zone in var.zones :
    format("zone-%d", substr(zone, -1, -2))
  ]

  bastion_sg_variable_cidr_list = split(",", var.network_cidr)

  bastion_sg_variable_cidr = flatten([
    local.schematics_reserved_cidrs,
    var.allowed_cidr
    # var.network_cidr
  ])

  # Security group rules
  bastion_security_group_rules = flatten([
    [for cidr in local.bastion_sg_variable_cidr : {
      name      = format("allow-variable-inbound-%s", index(local.bastion_sg_variable_cidr, cidr) + 1)
      direction = "inbound"
      remote    = cidr
      # ssh port
      tcp = {
        port_min = 22
        port_max = 22
      }
    }],
    [for cidr in local.bastion_sg_variable_cidr : {
      name      = format("allow-variable-outbound-%s", index(local.bastion_sg_variable_cidr, cidr) + 1)
      direction = "outbound"
      remote    = cidr
    }],
    [for cidr in local.bastion_sg_variable_cidr_list : {
      name      = format("allow-variable-inbound-cidr-%s", index(local.bastion_sg_variable_cidr_list, cidr) + 1)
      direction = "inbound"
      remote    = cidr
      tcp = {
        port_min = 22
        port_max = 22
      }
    }],
    [for cidr in local.bastion_sg_variable_cidr_list : {
      name      = format("allow-variable-outbound-cidr-%s", index(local.bastion_sg_variable_cidr_list, cidr) + 1)
      direction = "outbound"
      remote    = cidr
    }]
  ])

  # Address Prefixes calculation
  address_prefixes = {
    "zone-${element(split("-", var.zones[0]), 2)}" = [local.bastion_sg_variable_cidr_list[0]]
  }

  # Subnet calculation
  active_subnets = {
    for zone in local.zones : zone => contains(local.active_zones, zone) ? [
      {
        name           = "compute-subnet-${zone}"
        acl_name       = "vpc-acl"
        cidr           = var.compute_subnets_cidr[index(local.active_zones, zone)]
        public_gateway = true
      },
      zone == local.active_zones[0] ? {
        name           = "bastion-subnet"
        acl_name       = "vpc-acl"
        cidr           = var.bastion_subnets_cidr[0]
        public_gateway = true
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
  cidrs_network_acl_rules = compact(flatten([local.schematics_reserved_cidrs, var.allowed_cidr, var.network_cidr, "161.26.0.0/16", "166.8.0.0/14", "0.0.0.0/0"]))
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

  network_acls = [
    {
      name                         = "vpc-acl"
      add_ibm_cloud_internal_rules = true
      add_vpc_connectivity_rules   = true
      prepend_ibm_rules            = true
      rules                        = local.network_acl_rules
    }
  ]
}
