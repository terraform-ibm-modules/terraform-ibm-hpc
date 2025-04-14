# define variables
locals {
  name   = "lsf"
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

  bastion_node_name = format("%s-%s", local.prefix, "bastion")

  bastion_machine_type = "cx2-4x8"
  bastion_image_name   = "ibm-ubuntu-22-04-4-minimal-amd64-3"

  bastion_image_id = data.ibm_is_image.bastion.id

  bastion_sg_variable_cidr_list = var.network_cidr
  # Security group rules
  # TODO: Fix SG rules
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

  # Derived configs
  # VPC

  # Subnets
  bastion_subnets = var.bastion_subnets

  # Bastion Security group rule update to connect with login node
  bastion_security_group_rule_update = [
    {
      name      = "inbound-rule-for-login-node-connection"
      direction = "inbound"
      remote    = var.bastion_security_group_id
    }
  ]

  # Bastion Security Group rule update with LDAP server
  ldap_security_group_rule = [
    {
      name      = "inbound-rule-for-ldap-node-connection"
      direction = "inbound"
      remote    = var.ldap_server
      tcp = {
        port_min = 389
        port_max = 389
      }
    }
  ]
}
