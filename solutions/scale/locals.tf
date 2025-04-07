# locals needed for ibm provider
locals {
  # Region and Zone calculations
  region = join("-", slice(split("-", var.zones[0]), 0, 2))
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
    existing_resource_group                          = var.existing_resource_group
    allowed_cidr                                     = var.allowed_cidr
    ssh_keys                                         = var.ssh_keys
    bastion_ssh_keys                                 = var.bastion_ssh_keys
    bastion_subnets_cidr                             = var.bastion_subnets_cidr
    compute_gui_password                             = var.compute_gui_password
    compute_gui_username                             = var.compute_gui_username
    compute_ssh_keys                                 = var.compute_ssh_keys
    compute_subnets_cidr                             = var.compute_subnets_cidr
    cos_instance_name                                = var.cos_instance_name
    dns_custom_resolver_id                           = var.dns_custom_resolver_id
    dns_instance_id                                  = var.dns_instance_id
    dns_domain_names                                 = var.dns_domain_names
    enable_atracker                                  = var.enable_atracker
    enable_bastion                                   = var.enable_bastion
    bastion_image                                    = var.bastion_image
    bastion_instance_profile                         = var.bastion_instance_profile
    enable_deployer                                  = var.enable_deployer
    deployer_image                                   = var.deployer_image
    deployer_instance_profile                        = var.deployer_instance_profile
    enable_cos_integration                           = var.enable_cos_integration
    enable_vpc_flow_logs                             = var.enable_vpc_flow_logs
    enable_vpn                                       = var.enable_vpn
    hpcs_instance_name                               = var.hpcs_instance_name
    key_management                                   = var.key_management
    client_instances                                 = var.client_instances
    client_ssh_keys                                  = var.client_ssh_keys
    client_subnets_cidr                              = var.client_subnets_cidr
    network_cidr                                     = var.network_cidr
    placement_strategy                               = var.placement_strategy
    prefix                                           = var.prefix
    protocol_instances                               = var.protocol_instances
    protocol_subnets_cidr                            = var.protocol_subnets_cidr
    compute_instances                                = var.compute_instances
    storage_gui_password                             = var.storage_gui_password
    storage_gui_username                             = var.storage_gui_username
    storage_instances                                = var.storage_instances
    storage_ssh_keys                                 = var.storage_ssh_keys
    storage_subnets_cidr                             = var.storage_subnets_cidr
    vpc_name                                         = var.vpc_name
    vpn_peer_address                                 = var.vpn_peer_address
    vpn_peer_cidr                                    = var.vpn_peer_cidr
    vpn_preshared_key                                = var.vpn_preshared_key
    observability_atracker_enable                    = var.observability_atracker_enable
    observability_atracker_target_type               = var.observability_atracker_target_type
    observability_monitoring_enable                  = var.observability_monitoring_enable
    observability_logs_enable_for_management         = var.observability_logs_enable_for_management
    observability_logs_enable_for_compute            = var.observability_logs_enable_for_compute
    observability_enable_platform_logs               = var.observability_enable_platform_logs
    observability_enable_metrics_routing             = var.observability_enable_metrics_routing
    observability_logs_retention_period              = var.observability_logs_retention_period
    observability_monitoring_on_compute_nodes_enable = var.observability_monitoring_on_compute_nodes_enable
    observability_monitoring_plan                    = var.observability_monitoring_plan
    scc_enable                                       = var.scc_enable
    scc_profile                                      = var.scc_profile
    # scc_profile_version                              = var.scc_profile_version
    scc_location                                     = var.scc_location
    scc_event_notification_plan                      = var.scc_event_notification_plan
    skip_flowlogs_s2s_auth_policy                    = var.skip_flowlogs_s2s_auth_policy
    skip_iam_authorization_policy                    = var.skip_iam_authorization_policy
    skip_kms_s2s_auth_policy                         = var.skip_kms_s2s_auth_policy
    ibmcloud_api_key                                 = var.ibmcloud_api_key
    afm_instances                                    = var.afm_instances
    afm_cos_config                                   = var.afm_cos_config 
    enable_ldap                                      = var.enable_ldap
    ldap_basedns                                     = var.ldap_basedns
    ldap_admin_password                              = var.ldap_admin_password
    ldap_user_name                                   = var.ldap_user_name
    ldap_user_password                               = var.ldap_user_password
    ldap_server                                      = var.ldap_server
    ldap_server_cert                                 = var.ldap_server_cert
    ldap_instances                                   = var.ldap_instances
    scale_encryption_enabled                         = var.scale_encryption_enabled
    scale_encryption_type                            = var.scale_encryption_type
    gklm_instance_key_pair                           = var.gklm_instance_key_pair
    gklm_instances                                   = var.gklm_instances
    storage_type                                     = var.storage_type
    colocate_protocol_cluster_instances              = var.colocate_protocol_cluster_instances
    scale_encryption_admin_default_password          = var.scale_encryption_admin_default_password
    scale_encryption_admin_password                  = var.scale_encryption_admin_password
    scale_encryption_admin_username                  = var.scale_encryption_admin_username
    filesystem_config                                = var.filesystem_config
  }
}


# Compile Environment for Config output
locals {
  env = {
    existing_resource_group                          = lookup(local.override[local.override_type], "existing_resource_group", local.config.existing_resource_group)
    allowed_cidr                                     = lookup(local.override[local.override_type], "allowed_cidr", local.config.allowed_cidr)
    ssh_keys                                         = lookup(local.override[local.override_type], "ssh_keys", local.config.ssh_keys)
    bastion_ssh_keys                                 = lookup(local.override[local.override_type], "bastion_ssh_keys", local.config.bastion_ssh_keys)
    bastion_subnets_cidr                             = lookup(local.override[local.override_type], "bastion_subnets_cidr", local.config.bastion_subnets_cidr)
    compute_gui_password                             = lookup(local.override[local.override_type], "compute_gui_password", local.config.compute_gui_password)
    compute_gui_username                             = lookup(local.override[local.override_type], "compute_gui_username", local.config.compute_gui_username)
    compute_ssh_keys                                 = lookup(local.override[local.override_type], "compute_ssh_keys", local.config.compute_ssh_keys)
    compute_subnets_cidr                             = lookup(local.override[local.override_type], "compute_subnets_cidr", local.config.compute_subnets_cidr)
    cos_instance_name                                = lookup(local.override[local.override_type], "cos_instance_name", local.config.cos_instance_name)
    dns_custom_resolver_id                           = lookup(local.override[local.override_type], "dns_custom_resolver_id", local.config.dns_custom_resolver_id)
    dns_instance_id                                  = lookup(local.override[local.override_type], "dns_instance_id", local.config.dns_instance_id)
    dns_domain_names                                 = lookup(local.override[local.override_type], "dns_domain_names", local.config.dns_domain_names)
    enable_atracker                                  = lookup(local.override[local.override_type], "enable_atracker", local.config.enable_atracker)
    enable_bastion                                   = lookup(local.override[local.override_type], "enable_bastion", local.config.enable_bastion)
    bastion_image                                    = lookup(local.override[local.override_type], "bastion_image", local.config.bastion_image)
    bastion_instance_profile                         = lookup(local.override[local.override_type], "bastion_instance_profile", local.config.bastion_instance_profile)
    enable_deployer                                  = lookup(local.override[local.override_type], "enable_deployer", local.config.enable_deployer)
    deployer_image                                   = lookup(local.override[local.override_type], "deployer_image", local.config.deployer_image)
    deployer_instance_profile                        = lookup(local.override[local.override_type], "deployer_instance_profile", local.config.deployer_instance_profile)
    enable_cos_integration                           = lookup(local.override[local.override_type], "enable_cos_integration", local.config.enable_cos_integration)
    enable_vpc_flow_logs                             = lookup(local.override[local.override_type], "enable_vpc_flow_logs", local.config.enable_vpc_flow_logs)
    enable_vpn                                       = lookup(local.override[local.override_type], "enable_vpn", local.config.enable_vpn)
    hpcs_instance_name                               = lookup(local.override[local.override_type], "hpcs_instance_name", local.config.hpcs_instance_name)
    key_management                                   = lookup(local.override[local.override_type], "key_management", local.config.key_management)
    client_instances                                 = lookup(local.override[local.override_type], "client_instances", local.config.client_instances)
    client_ssh_keys                                  = lookup(local.override[local.override_type], "client_ssh_keys", local.config.client_ssh_keys)
    client_subnets_cidr                              = lookup(local.override[local.override_type], "client_subnets_cidr", local.config.client_subnets_cidr)
    network_cidr                                     = lookup(local.override[local.override_type], "network_cidr", local.config.network_cidr)
    placement_strategy                               = lookup(local.override[local.override_type], "placement_strategy", local.config.placement_strategy)
    prefix                                           = lookup(local.override[local.override_type], "prefix", local.config.prefix)
    protocol_instances                               = lookup(local.override[local.override_type], "protocol_instances", local.config.protocol_instances)
    protocol_subnets_cidr                            = lookup(local.override[local.override_type], "protocol_subnets_cidr", local.config.protocol_subnets_cidr)
    compute_instances                                = lookup(local.override[local.override_type], "compute_instances", local.config.compute_instances)
    storage_gui_password                             = lookup(local.override[local.override_type], "storage_gui_password", local.config.storage_gui_password)
    storage_gui_username                             = lookup(local.override[local.override_type], "storage_gui_username", local.config.storage_gui_username)
    storage_instances                                = lookup(local.override[local.override_type], "storage_instances", local.config.storage_instances)
    storage_ssh_keys                                 = lookup(local.override[local.override_type], "storage_ssh_keys", local.config.storage_ssh_keys)
    storage_subnets_cidr                             = lookup(local.override[local.override_type], "storage_subnets_cidr", local.config.storage_subnets_cidr)
    vpc_name                                         = lookup(local.override[local.override_type], "vpc_name", local.config.vpc_name)
    vpn_peer_address                                 = lookup(local.override[local.override_type], "vpn_peer_address", local.config.vpn_peer_address)
    vpn_peer_cidr                                    = lookup(local.override[local.override_type], "vpn_peer_cidr", local.config.vpn_peer_cidr)
    vpn_preshared_key                                = lookup(local.override[local.override_type], "vpn_preshared_key", local.config.vpn_preshared_key)
    observability_atracker_enable                    = lookup(local.override[local.override_type], "observability_atracker_enable", local.config.observability_atracker_enable)
    observability_atracker_target_type               = lookup(local.override[local.override_type], "observability_atracker_target_type", local.config.observability_atracker_target_type)
    observability_monitoring_enable                  = lookup(local.override[local.override_type], "observability_monitoring_enable", local.config.observability_monitoring_enable)
    observability_logs_enable_for_management         = lookup(local.override[local.override_type], "observability_logs_enable_for_management", local.config.observability_logs_enable_for_management)
    observability_logs_enable_for_compute            = lookup(local.override[local.override_type], "observability_logs_enable_for_compute", local.config.observability_logs_enable_for_compute)
    observability_enable_platform_logs               = lookup(local.override[local.override_type], "observability_enable_platform_logs", local.config.observability_enable_platform_logs)
    observability_enable_metrics_routing             = lookup(local.override[local.override_type], "observability_enable_metrics_routing", local.config.observability_enable_metrics_routing)
    observability_logs_retention_period              = lookup(local.override[local.override_type], "observability_logs_retention_period", local.config.observability_logs_retention_period)
    observability_monitoring_on_compute_nodes_enable = lookup(local.override[local.override_type], "observability_monitoring_on_compute_nodes_enable", local.config.observability_monitoring_on_compute_nodes_enable)
    observability_monitoring_plan                    = lookup(local.override[local.override_type], "observability_monitoring_plan", local.config.observability_monitoring_plan)
    scc_enable                                       = lookup(local.override[local.override_type], "scc_enable", local.config.scc_enable)
    scc_profile                                      = lookup(local.override[local.override_type], "scc_profile", local.config.scc_profile)
    # scc_profile_version                              = lookup(local.override[local.override_type], "scc_profile_version", local.config.scc_profile_version)
    scc_location                                     = lookup(local.override[local.override_type], "scc_location", local.config.scc_location)
    scc_event_notification_plan                      = lookup(local.override[local.override_type], "scc_event_notification_plan", local.config.scc_event_notification_plan)
    skip_flowlogs_s2s_auth_policy                    = lookup(local.override[local.override_type], "skip_flowlogs_s2s_auth_policy", local.config.skip_flowlogs_s2s_auth_policy)
    skip_iam_authorization_policy                    = lookup(local.override[local.override_type], "skip_iam_authorization_policy", local.config.skip_iam_authorization_policy)
    skip_kms_s2s_auth_policy                         = lookup(local.override[local.override_type], "skip_kms_s2s_auth_policy", local.config.skip_kms_s2s_auth_policy)
    ibmcloud_api_key                                 = lookup(local.override[local.override_type], "ibmcloud_api_key", local.config.ibmcloud_api_key)
    afm_instances                                    = lookup(local.override[local.override_type], "afm_instances", local.config.afm_instances)
    afm_cos_config                                   = lookup(local.override[local.override_type], "afm_cos_config", local.config.afm_cos_config)
    enable_ldap                                      = lookup(local.override[local.override_type], "enable_ldap", local.config.enable_ldap)
    ldap_basedns                                     = lookup(local.override[local.override_type], "ldap_basedns", local.config.ldap_basedns)
    ldap_admin_password                              = lookup(local.override[local.override_type], "ldap_admin_password", local.config.ldap_admin_password)
    ldap_user_name                                   = lookup(local.override[local.override_type], "ldap_user_name", local.config.ldap_user_name)
    ldap_user_password                               = lookup(local.override[local.override_type], "ldap_user_password", local.config.ldap_user_password)
    ldap_server                                      = lookup(local.override[local.override_type], "ldap_server", local.config.ldap_server)
    ldap_server_cert                                 = lookup(local.override[local.override_type], "ldap_server_cert", local.config.ldap_server_cert)
    ldap_instances                                   = lookup(local.override[local.override_type], "ldap_instances", local.config.ldap_instances)
    scale_encryption_enabled                         = lookup(local.override[local.override_type], "scale_encryption_enabled", local.config.scale_encryption_enabled)
    scale_encryption_type                            = lookup(local.override[local.override_type], "scale_encryption_type", local.config.scale_encryption_type)
    gklm_instance_key_pair                           = lookup(local.override[local.override_type], "gklm_instance_key_pair", local.config.gklm_instance_key_pair)
    gklm_instances                                   = lookup(local.override[local.override_type], "gklm_instances", local.config.gklm_instances)
    storage_type                                     = lookup(local.override[local.override_type], "storage_type", local.config.storage_type)
    colocate_protocol_cluster_instances              = lookup(local.override[local.override_type], "colocate_protocol_cluster_instances", local.config.colocate_protocol_cluster_instances)
    scale_encryption_admin_default_password          = lookup(local.override[local.override_type], "scale_encryption_admin_default_password", local.config.scale_encryption_admin_default_password)
    scale_encryption_admin_password                  = lookup(local.override[local.override_type], "scale_encryption_admin_password", local.config.scale_encryption_admin_password)
    scale_encryption_admin_username                  = lookup(local.override[local.override_type], "scale_encryption_admin_username", local.config.scale_encryption_admin_username)
    filesystem_config                                = lookup(local.override[local.override_type], "filesystem_config", local.config.filesystem_config)
  }
}
