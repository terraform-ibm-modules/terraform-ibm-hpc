# locals needed for ibm provider
locals {
  # Region and Zone calculations
  region = join("-", slice(split("-", var.zone), 0, 2))
}


locals {
  override_json_path = abspath("./override.json")
  override = {
    override = jsondecode(var.override && var.override_json_string == null ?
      (local.override_json_path == "" ? file("${path.root}/override.json") : file(local.override_json_path))
      :
    "{}")
    override_json_string = jsondecode(var.override_json_string == null ? "{}" : var.override_json_string)
  }
  override_type = var.override_json_string == null ? "override" : "override_json_string"
}


locals {
  config = {
    resource_group            = var.resource_group
    allowed_cidr              = var.allowed_cidr
    deployer_instance_profile = var.deployer_instance_profile
    ssh_keys                  = var.ssh_keys
    bastion_ssh_keys          = var.bastion_ssh_keys
    bastion_subnets_cidr      = var.bastion_subnets_cidr
    compute_gui_password      = var.compute_gui_password
    compute_gui_username      = var.compute_gui_username
    compute_ssh_keys          = var.compute_ssh_keys
    compute_subnets_cidr      = var.compute_subnets_cidr
    cos_instance_name         = var.cos_instance_name
    dns_custom_resolver_id    = var.dns_custom_resolver_id
    dns_instance_id           = var.dns_instance_id
    dns_domain_names          = var.dns_domain_names
    dynamic_compute_instances = var.dynamic_compute_instances
    enable_atracker           = var.enable_atracker
    enable_bastion            = var.enable_bastion
    enable_deployer           = var.enable_deployer
    enable_cos_integration    = var.enable_cos_integration
    enable_vpc_flow_logs      = var.enable_vpc_flow_logs
    enable_vpn                = var.enable_vpn
    file_shares               = var.file_shares
    hpcs_instance_name        = var.hpcs_instance_name
    key_management            = var.key_management
    client_instances          = var.client_instances
    client_ssh_keys           = var.client_ssh_keys
    client_subnets_cidr       = var.client_subnets_cidr
    management_instances      = var.management_instances
    network_cidr              = var.network_cidr
    placement_strategy        = var.placement_strategy
    prefix                    = var.prefix
    protocol_instances        = var.protocol_instances
    protocol_subnets_cidr     = var.protocol_subnets_cidr
    static_compute_instances  = var.static_compute_instances
    storage_gui_password      = var.storage_gui_password
    storage_gui_username      = var.storage_gui_username
    storage_instances         = var.storage_instances
    storage_ssh_keys          = var.storage_ssh_keys
    storage_subnets_cidr      = var.storage_subnets_cidr
    vpc                       = var.vpc
    vpn_peer_address          = var.vpn_peer_address
    vpn_peer_cidr             = var.vpn_peer_cidr
    vpn_preshared_key         = var.vpn_preshared_key
  }
}


# Compile Environment for Config output
locals {
  env = {
    resource_group            = lookup(local.override[local.override_type], "resource_group", local.config.resource_group)
    allowed_cidr              = lookup(local.override[local.override_type], "allowed_cidr", local.config.allowed_cidr)
    deployer_instance_profile = lookup(local.override[local.override_type], "deployer_instance_profile", local.config.deployer_instance_profile)
    ssh_keys                  = lookup(local.override[local.override_type], "ssh_keys", local.config.ssh_keys)
    bastion_ssh_keys          = lookup(local.override[local.override_type], "bastion_ssh_keys", local.config.bastion_ssh_keys)
    bastion_subnets_cidr      = lookup(local.override[local.override_type], "bastion_subnets_cidr", local.config.bastion_subnets_cidr)
    compute_gui_password      = lookup(local.override[local.override_type], "compute_gui_password", local.config.compute_gui_password)
    compute_gui_username      = lookup(local.override[local.override_type], "compute_gui_username", local.config.compute_gui_username)
    compute_ssh_keys          = lookup(local.override[local.override_type], "compute_ssh_keys", local.config.compute_ssh_keys)
    compute_subnets_cidr      = lookup(local.override[local.override_type], "compute_subnets_cidr", local.config.compute_subnets_cidr)
    cos_instance_name         = lookup(local.override[local.override_type], "cos_instance_name", local.config.cos_instance_name)
    dns_custom_resolver_id    = lookup(local.override[local.override_type], "dns_custom_resolver_id", local.config.dns_custom_resolver_id)
    dns_instance_id           = lookup(local.override[local.override_type], "dns_instance_id", local.config.dns_instance_id)
    dns_domain_names          = lookup(local.override[local.override_type], "dns_domain_names", local.config.dns_domain_names)
    dynamic_compute_instances = lookup(local.override[local.override_type], "dynamic_compute_instances", local.config.dynamic_compute_instances)
    enable_atracker           = lookup(local.override[local.override_type], "enable_atracker", local.config.enable_atracker)
    enable_bastion            = lookup(local.override[local.override_type], "enable_bastion", local.config.enable_bastion)
    enable_deployer           = lookup(local.override[local.override_type], "enable_deployer", local.config.enable_deployer)
    enable_cos_integration    = lookup(local.override[local.override_type], "enable_cos_integration", local.config.enable_cos_integration)
    enable_vpc_flow_logs      = lookup(local.override[local.override_type], "enable_vpc_flow_logs", local.config.enable_vpc_flow_logs)
    enable_vpn                = lookup(local.override[local.override_type], "enable_vpn", local.config.enable_vpn)
    file_shares               = lookup(local.override[local.override_type], "file_shares", local.config.file_shares)
    hpcs_instance_name        = lookup(local.override[local.override_type], "hpcs_instance_name", local.config.hpcs_instance_name)
    key_management            = lookup(local.override[local.override_type], "key_management", local.config.key_management)
    client_instances          = lookup(local.override[local.override_type], "client_instances", local.config.client_instances)
    client_ssh_keys           = lookup(local.override[local.override_type], "client_ssh_keys", local.config.client_ssh_keys)
    client_subnets_cidr       = lookup(local.override[local.override_type], "client_subnets_cidr", local.config.client_subnets_cidr)
    management_instances      = lookup(local.override[local.override_type], "management_instances", local.config.management_instances)
    network_cidr              = lookup(local.override[local.override_type], "network_cidr", local.config.network_cidr)
    placement_strategy        = lookup(local.override[local.override_type], "placement_strategy", local.config.placement_strategy)
    prefix                    = lookup(local.override[local.override_type], "prefix", local.config.prefix)
    protocol_instances        = lookup(local.override[local.override_type], "protocol_instances", local.config.protocol_instances)
    protocol_subnets_cidr     = lookup(local.override[local.override_type], "protocol_subnets_cidr", local.config.protocol_subnets_cidr)
    static_compute_instances  = lookup(local.override[local.override_type], "static_compute_instances", local.config.static_compute_instances)
    storage_gui_password      = lookup(local.override[local.override_type], "storage_gui_password", local.config.storage_gui_password)
    storage_gui_username      = lookup(local.override[local.override_type], "storage_gui_username", local.config.storage_gui_username)
    storage_instances         = lookup(local.override[local.override_type], "storage_instances", local.config.storage_instances)
    storage_ssh_keys          = lookup(local.override[local.override_type], "storage_ssh_keys", local.config.storage_ssh_keys)
    storage_subnets_cidr      = lookup(local.override[local.override_type], "storage_subnets_cidr", local.config.storage_subnets_cidr)
    vpc                       = lookup(local.override[local.override_type], "vpc", local.config.vpc)
    vpn_peer_address          = lookup(local.override[local.override_type], "vpn_peer_address", local.config.vpn_peer_address)
    vpn_peer_cidr             = lookup(local.override[local.override_type], "vpn_peer_cidr", local.config.vpn_peer_cidr)
    vpn_preshared_key         = lookup(local.override[local.override_type], "vpn_preshared_key", local.config.vpn_preshared_key)
  }
}