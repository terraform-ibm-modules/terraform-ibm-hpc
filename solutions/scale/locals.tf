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
    resource_group                  = var.resource_group
    allowed_cidr                    = var.allowed_cidr
    deployer_instance_profile       = var.deployer_instance_profile
    ssh_keys                        = var.ssh_keys
    bastion_ssh_keys                = var.bastion_ssh_keys
    bastion_subnets_cidr            = var.bastion_subnets_cidr
    compute_gui_password            = var.compute_gui_password
    compute_gui_username            = var.compute_gui_username
    compute_ssh_keys                = var.compute_ssh_keys
    compute_subnets_cidr            = var.compute_subnets_cidr
    cos_instance_name               = var.cos_instance_name
    dns_custom_resolver_id          = var.dns_custom_resolver_id
    dns_instance_id                 = var.dns_instance_id
    dns_domain_names                = var.dns_domain_names
    enable_atracker                 = var.enable_atracker
    enable_bastion                  = var.enable_bastion
    bastion_image                   = var.bastion_image
    bastion_instance_profile        = var.bastion_instance_profile
    enable_deployer                 = var.enable_deployer
    deployer_image                  = var.deployer_image
    deployer_instance_profile       = var.deployer_instance_profile
    enable_cos_integration          = var.enable_cos_integration
    enable_vpc_flow_logs            = var.enable_vpc_flow_logs
    enable_vpn                      = var.enable_vpn
    hpcs_instance_name              = var.hpcs_instance_name
    key_management                  = var.key_management
    client_instances                = var.client_instances
    client_ssh_keys                 = var.client_ssh_keys
    client_subnets_cidr             = var.client_subnets_cidr
    network_cidr                    = var.network_cidr
    placement_strategy              = var.placement_strategy
    prefix                          = var.prefix
    protocol_instances              = var.protocol_instances
    protocol_subnets_cidr           = var.protocol_subnets_cidr
    compute_instances               = var.compute_instances
    storage_gui_password            = var.storage_gui_password
    storage_gui_username            = var.storage_gui_username
    storage_instances               = var.storage_instances
    storage_ssh_keys                = var.storage_ssh_keys
    storage_subnets_cidr            = var.storage_subnets_cidr
    vpc                             = var.vpc
    vpn_peer_address                = var.vpn_peer_address
    vpn_peer_cidr                   = var.vpn_peer_cidr
    vpn_preshared_key               = var.vpn_preshared_key
    file_shares                     = var.file_shares
    enable_ldap                     = var.enable_ldap
    ldap_basedns                    = var.ldap_basedns
    ldap_vsi_profile                = var.ldap_vsi_profile
    ldap_admin_password             = var.ldap_admin_password
    ldap_user_name                  = var.ldap_user_name
    ldap_user_password              = var.ldap_user_password
    ldap_server                     = var.ldap_server
    ldap_server_cert                = var.ldap_server_cert
    ldap_vsi_osimage_name           = var.ldap_vsi_osimage_name
    afm_cos_config                  = var.afm_cos_config
    afm_instances                   = var.afm_instances
    scale_encryption_enabled        = var.scale_encryption_enabled
    scale_encryption_type           = var.scale_encryption_type
    scale_encryption_admin_password = var.scale_encryption_admin_password
    gklm_instances                  = var.gklm_instances
    gklm_instance_key_pair          = var.gklm_instance_key_pair

  }
}


# Compile Environment for Config output
locals {
  env = {
    resource_group                  = lookup(local.override[local.override_type], "resource_group", local.config.resource_group)
    allowed_cidr                    = lookup(local.override[local.override_type], "allowed_cidr", local.config.allowed_cidr)
    ssh_keys                        = lookup(local.override[local.override_type], "ssh_keys", local.config.ssh_keys)
    bastion_ssh_keys                = lookup(local.override[local.override_type], "bastion_ssh_keys", local.config.bastion_ssh_keys)
    bastion_subnets_cidr            = lookup(local.override[local.override_type], "bastion_subnets_cidr", local.config.bastion_subnets_cidr)
    compute_gui_password            = lookup(local.override[local.override_type], "compute_gui_password", local.config.compute_gui_password)
    compute_gui_username            = lookup(local.override[local.override_type], "compute_gui_username", local.config.compute_gui_username)
    compute_ssh_keys                = lookup(local.override[local.override_type], "compute_ssh_keys", local.config.compute_ssh_keys)
    compute_subnets_cidr            = lookup(local.override[local.override_type], "compute_subnets_cidr", local.config.compute_subnets_cidr)
    cos_instance_name               = lookup(local.override[local.override_type], "cos_instance_name", local.config.cos_instance_name)
    dns_custom_resolver_id          = lookup(local.override[local.override_type], "dns_custom_resolver_id", local.config.dns_custom_resolver_id)
    dns_instance_id                 = lookup(local.override[local.override_type], "dns_instance_id", local.config.dns_instance_id)
    dns_domain_names                = lookup(local.override[local.override_type], "dns_domain_names", local.config.dns_domain_names)
    enable_atracker                 = lookup(local.override[local.override_type], "enable_atracker", local.config.enable_atracker)
    enable_bastion                  = lookup(local.override[local.override_type], "enable_bastion", local.config.enable_bastion)
    bastion_image                   = lookup(local.override[local.override_type], "bastion_image", local.config.bastion_image)
    bastion_instance_profile        = lookup(local.override[local.override_type], "bastion_instance_profile", local.config.bastion_instance_profile)
    enable_deployer                 = lookup(local.override[local.override_type], "enable_deployer", local.config.enable_deployer)
    deployer_image                  = lookup(local.override[local.override_type], "deployer_image", local.config.deployer_image)
    deployer_instance_profile       = lookup(local.override[local.override_type], "deployer_instance_profile", local.config.deployer_instance_profile)
    enable_cos_integration          = lookup(local.override[local.override_type], "enable_cos_integration", local.config.enable_cos_integration)
    enable_vpc_flow_logs            = lookup(local.override[local.override_type], "enable_vpc_flow_logs", local.config.enable_vpc_flow_logs)
    enable_vpn                      = lookup(local.override[local.override_type], "enable_vpn", local.config.enable_vpn)
    hpcs_instance_name              = lookup(local.override[local.override_type], "hpcs_instance_name", local.config.hpcs_instance_name)
    key_management                  = lookup(local.override[local.override_type], "key_management", local.config.key_management)
    client_instances                = lookup(local.override[local.override_type], "client_instances", local.config.client_instances)
    client_ssh_keys                 = lookup(local.override[local.override_type], "client_ssh_keys", local.config.client_ssh_keys)
    client_subnets_cidr             = lookup(local.override[local.override_type], "client_subnets_cidr", local.config.client_subnets_cidr)
    network_cidr                    = lookup(local.override[local.override_type], "network_cidr", local.config.network_cidr)
    placement_strategy              = lookup(local.override[local.override_type], "placement_strategy", local.config.placement_strategy)
    prefix                          = lookup(local.override[local.override_type], "prefix", local.config.prefix)
    protocol_instances              = lookup(local.override[local.override_type], "protocol_instances", local.config.protocol_instances)
    protocol_subnets_cidr           = lookup(local.override[local.override_type], "protocol_subnets_cidr", local.config.protocol_subnets_cidr)
    compute_instances               = lookup(local.override[local.override_type], "compute_instances", local.config.compute_instances)
    storage_gui_password            = lookup(local.override[local.override_type], "storage_gui_password", local.config.storage_gui_password)
    storage_gui_username            = lookup(local.override[local.override_type], "storage_gui_username", local.config.storage_gui_username)
    storage_instances               = lookup(local.override[local.override_type], "storage_instances", local.config.storage_instances)
    storage_ssh_keys                = lookup(local.override[local.override_type], "storage_ssh_keys", local.config.storage_ssh_keys)
    storage_subnets_cidr            = lookup(local.override[local.override_type], "storage_subnets_cidr", local.config.storage_subnets_cidr)
    vpc                             = lookup(local.override[local.override_type], "vpc", local.config.vpc)
    vpn_peer_address                = lookup(local.override[local.override_type], "vpn_peer_address", local.config.vpn_peer_address)
    vpn_peer_cidr                   = lookup(local.override[local.override_type], "vpn_peer_cidr", local.config.vpn_peer_cidr)
    vpn_preshared_key               = lookup(local.override[local.override_type], "vpn_preshared_key", local.config.vpn_preshared_key)
    file_shares                     = lookup(local.override[local.override_type], "file_shares", local.config.file_shares)
    enable_ldap                     = lookup(local.override[local.override_type], "enable_ldap", local.config.enable_ldap)
    ldap_basedns                    = lookup(local.override[local.override_type], "ldap_basedns", local.config.ldap_basedns)
    ldap_vsi_profile                = lookup(local.override[local.override_type], "ldap_vsi_profile", local.config.ldap_vsi_profile)
    ldap_admin_password             = lookup(local.override[local.override_type], "ldap_admin_password", local.config.ldap_admin_password)
    ldap_user_name                  = lookup(local.override[local.override_type], "ldap_user_name", local.config.ldap_user_name)
    ldap_user_password              = lookup(local.override[local.override_type], "ldap_user_password", local.config.ldap_user_password)
    ldap_server                     = lookup(local.override[local.override_type], "ldap_server", local.config.ldap_server)
    ldap_server_cert                = lookup(local.override[local.override_type], "ldap_server_cert", local.config.ldap_server_cert)
    ldap_vsi_osimage_name           = lookup(local.override[local.override_type], "ldap_vsi_osimage_name", local.config.ldap_vsi_osimage_name)
    afm_cos_config                  = lookup(local.override[local.override_type], "afm_cos_config", local.config.afm_cos_config)
    afm_instances                   = lookup(local.override[local.override_type], "afm_instances", local.config.afm_instances)
    scale_encryption_enabled        = lookup(local.override[local.override_type], "scale_encryption_enabled", local.config.scale_encryption_enabled)
    scale_encryption_type           = lookup(local.override[local.override_type], "scale_encryption_type", local.config.scale_encryption_type)
    scale_encryption_admin_password = lookup(local.override[local.override_type], "scale_encryption_admin_password", local.config.scale_encryption_admin_password)
    gklm_instances                  = lookup(local.override[local.override_type], "gklm_instances", local.config.gklm_instances)
    gklm_instance_key_pair          = lookup(local.override[local.override_type], "gklm_instance_key_pair", local.config.gklm_instance_key_pair)
  }
}
