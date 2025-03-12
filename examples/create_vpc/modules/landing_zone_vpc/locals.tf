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

  bastion_sg_variable_cidr = flatten([
    local.schematics_reserved_cidrs,
    var.allowed_cidr
    # var.network_cidr
  ])
  resource_group_id = var.existing_resource_group != null ? data.ibm_resource_group.resource_group.id : ""

  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))
  zones  = ["zone-1", "zone-2", "zone-3"]
  active_zones = [
    for zone in var.zones :
    format("zone-%d", substr(zone, -1, -2))
  ]
}

locals {
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
        public_gateway = false
      } : null
    ] : []
  }
  subnets = { for zone, subnets in local.active_subnets : zone => [for each in subnets : each if each != null] }

  # Use public gateway calculation
  use_public_gateways = {
    for zone in local.zones : zone => contains(local.active_zones, zone) ? true : false
  }
}

locals {
  # Address_Prefix calculation

  bastion_sg_variable_cidr_list = split(",", var.network_cidr)
  address_prefixes = {
    "zone-${element(split("-", var.zones[0]), 2)}" = [local.bastion_sg_variable_cidr_list[0]]
  }

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
}

locals {
  #   # VPC calculation
  #   # If user defined then use existing else create new
  #   # Calculate network acl rules (can be done inplace in vpcs)
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
