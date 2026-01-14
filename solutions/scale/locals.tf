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
    existing_resource_group              = var.existing_resource_group
    remote_allowed_ips                   = var.remote_allowed_ips
    ssh_keys                             = var.ssh_keys
    login_subnets_cidr                   = var.login_subnets_cidr
    compute_gui_password                 = var.compute_gui_password
    compute_gui_username                 = var.compute_gui_username
    compute_subnets_cidr                 = var.compute_subnets_cidr
    cos_instance_name                    = var.cos_instance_name
    dns_custom_resolver_id               = var.dns_custom_resolver_id
    dns_instance_id                      = var.dns_instance_id
    dns_domain_names                     = var.dns_domain_names
    bastion_instance                     = var.bastion_instance
    deployer_instance                    = var.deployer_instance
    enable_cos_integration               = var.enable_cos_integration
    enable_vpc_flow_logs                 = var.enable_vpc_flow_logs
    client_instances                     = var.client_instances
    client_subnets_cidr                  = var.client_subnets_cidr
    vpc_cidr                             = var.vpc_cidr
    cluster_prefix                       = var.cluster_prefix
    protocol_instances                   = var.protocol_instances
    protocol_subnets_cidr                = var.protocol_subnets_cidr
    compute_instances                    = var.compute_instances
    storage_gui_password                 = var.storage_gui_password
    storage_gui_username                 = var.storage_gui_username
    storage_instances                    = var.storage_instances
    storage_baremetal_server             = var.storage_baremetal_server
    storage_subnets_cidr                 = var.storage_subnets_cidr
    vpc_name                             = var.vpc_name
    observability_atracker_enable        = var.observability_atracker_enable
    observability_atracker_target_type   = var.observability_atracker_target_type
    sccwp_service_plan                   = var.sccwp_service_plan
    sccwp_enable                         = var.sccwp_enable
    cspm_enabled                         = var.cspm_enabled
    app_config_plan                      = var.app_config_plan
    skip_flowlogs_s2s_auth_policy        = var.skip_flowlogs_s2s_auth_policy
    ibmcloud_api_key                     = var.ibmcloud_api_key
    afm_instances                        = var.afm_instances
    afm_cos_config                       = var.afm_cos_config
    enable_ldap                          = var.enable_ldap
    ldap_basedns                         = var.ldap_basedns
    ldap_admin_password                  = var.ldap_admin_password
    ldap_user_name                       = var.ldap_user_name
    ldap_user_password                   = var.ldap_user_password
    ldap_server                          = var.ldap_server
    ldap_server_cert                     = var.ldap_server_cert
    ldap_instance                        = var.ldap_instance
    scale_encryption_enabled             = var.scale_encryption_enabled
    scale_encryption_type                = var.scale_encryption_type
    gklm_instances                       = var.gklm_instances
    storage_type                         = var.storage_type
    colocate_protocol_instances          = var.colocate_protocol_instances
    scale_encryption_admin_password      = var.scale_encryption_admin_password
    key_protect_instance_id              = var.key_protect_instance_id
    filesystem_config                    = var.filesystem_config
    existing_bastion_instance_name       = var.existing_bastion_instance_name
    existing_bastion_instance_public_ip  = var.existing_bastion_instance_public_ip
    existing_bastion_security_group_id   = var.existing_bastion_security_group_id
    existing_bastion_ssh_private_key     = var.existing_bastion_ssh_private_key
    bms_boot_drive_encryption            = var.bms_boot_drive_encryption
    tie_breaker_baremetal_server_profile = var.tie_breaker_baremetal_server_profile
    filesets_config                      = var.filesets_config
    login_security_group_name            = var.login_security_group_name
    storage_security_group_name          = var.storage_security_group_name
    compute_security_group_name          = var.compute_security_group_name
    client_security_group_name           = var.client_security_group_name
    gklm_security_group_name             = var.gklm_security_group_name
    ldap_security_group_name             = var.ldap_security_group_name
    login_subnet_id                      = var.login_subnet_id
    compute_subnet_id                    = var.compute_subnet_id
    storage_subnet_id                    = var.storage_subnet_id
    protocol_subnet_id                   = var.protocol_subnet_id
    client_subnet_id                     = var.client_subnet_id
    scale_management_vsi_profile         = var.scale_management_vsi_profile
    volume_storages                      = var.volume_storages
    enable_private_path_nlb              = var.enable_private_path_nlb
    protocol_instance_eth1_mtu           = var.protocol_instance_eth1_mtu
  }
}


# Compile Environment for Config output
locals {
  env = {
    existing_resource_group              = lookup(local.override[local.override_type], "existing_resource_group", local.config.existing_resource_group)
    remote_allowed_ips                   = lookup(local.override[local.override_type], "remote_allowed_ips", local.config.remote_allowed_ips)
    ssh_keys                             = lookup(local.override[local.override_type], "ssh_keys", local.config.ssh_keys)
    login_subnets_cidr                   = lookup(local.override[local.override_type], "login_subnets_cidr", local.config.login_subnets_cidr)
    compute_gui_password                 = lookup(local.override[local.override_type], "compute_gui_password", local.config.compute_gui_password)
    compute_gui_username                 = lookup(local.override[local.override_type], "compute_gui_username", local.config.compute_gui_username)
    compute_subnets_cidr                 = lookup(local.override[local.override_type], "compute_subnets_cidr", local.config.compute_subnets_cidr)
    cos_instance_name                    = lookup(local.override[local.override_type], "cos_instance_name", local.config.cos_instance_name)
    dns_custom_resolver_id               = lookup(local.override[local.override_type], "dns_custom_resolver_id", local.config.dns_custom_resolver_id)
    dns_instance_id                      = lookup(local.override[local.override_type], "dns_instance_id", local.config.dns_instance_id)
    dns_domain_names                     = lookup(local.override[local.override_type], "dns_domain_names", local.config.dns_domain_names)
    bastion_instance                     = lookup(local.override[local.override_type], "bastion_instance", local.config.bastion_instance)
    deployer_instance                    = lookup(local.override[local.override_type], "deployer_instance", local.config.deployer_instance)
    enable_cos_integration               = lookup(local.override[local.override_type], "enable_cos_integration", local.config.enable_cos_integration)
    enable_vpc_flow_logs                 = lookup(local.override[local.override_type], "enable_vpc_flow_logs", local.config.enable_vpc_flow_logs)
    client_instances                     = lookup(local.override[local.override_type], "client_instances", local.config.client_instances)
    client_subnets_cidr                  = lookup(local.override[local.override_type], "client_subnets_cidr", local.config.client_subnets_cidr)
    vpc_cidr                             = lookup(local.override[local.override_type], "vpc_cidr", local.config.vpc_cidr)
    cluster_prefix                       = lookup(local.override[local.override_type], "cluster_prefix", local.config.cluster_prefix)
    protocol_instances                   = lookup(local.override[local.override_type], "protocol_instances", local.config.protocol_instances)
    protocol_subnets_cidr                = lookup(local.override[local.override_type], "protocol_subnets_cidr", local.config.protocol_subnets_cidr)
    compute_instances                    = lookup(local.override[local.override_type], "compute_instances", local.config.compute_instances)
    storage_gui_password                 = lookup(local.override[local.override_type], "storage_gui_password", local.config.storage_gui_password)
    storage_gui_username                 = lookup(local.override[local.override_type], "storage_gui_username", local.config.storage_gui_username)
    storage_instances                    = lookup(local.override[local.override_type], "storage_instances", local.config.storage_instances)
    storage_baremetal_server             = lookup(local.override[local.override_type], "storage_baremetal_server", local.config.storage_baremetal_server)
    storage_subnets_cidr                 = lookup(local.override[local.override_type], "storage_subnets_cidr", local.config.storage_subnets_cidr)
    vpc_name                             = lookup(local.override[local.override_type], "vpc_name", local.config.vpc_name)
    observability_atracker_enable        = lookup(local.override[local.override_type], "observability_atracker_enable", local.config.observability_atracker_enable)
    observability_atracker_target_type   = lookup(local.override[local.override_type], "observability_atracker_target_type", local.config.observability_atracker_target_type)
    sccwp_enable                         = lookup(local.override[local.override_type], "scc_wp_enable", local.config.sccwp_enable)
    cspm_enable                          = lookup(local.override[local.override_type], "cspm_enable", local.config.cspm_enabled)
    sccwp_service_plan                   = lookup(local.override[local.override_type], "scc_wp_service_plan", local.config.sccwp_service_plan)
    app_config_plan                      = lookup(local.override[local.override_type], "app_config_plan", local.config.app_config_plan)
    skip_flowlogs_s2s_auth_policy        = lookup(local.override[local.override_type], "skip_flowlogs_s2s_auth_policy", local.config.skip_flowlogs_s2s_auth_policy)
    ibmcloud_api_key                     = lookup(local.override[local.override_type], "ibmcloud_api_key", local.config.ibmcloud_api_key)
    afm_instances                        = lookup(local.override[local.override_type], "afm_instances", local.config.afm_instances)
    afm_cos_config                       = lookup(local.override[local.override_type], "afm_cos_config", local.config.afm_cos_config)
    enable_ldap                          = lookup(local.override[local.override_type], "enable_ldap", local.config.enable_ldap)
    ldap_basedns                         = lookup(local.override[local.override_type], "ldap_basedns", local.config.ldap_basedns)
    ldap_admin_password                  = lookup(local.override[local.override_type], "ldap_admin_password", local.config.ldap_admin_password)
    ldap_user_name                       = lookup(local.override[local.override_type], "ldap_user_name", local.config.ldap_user_name)
    ldap_user_password                   = lookup(local.override[local.override_type], "ldap_user_password", local.config.ldap_user_password)
    ldap_server                          = lookup(local.override[local.override_type], "ldap_server", local.config.ldap_server)
    ldap_server_cert                     = lookup(local.override[local.override_type], "ldap_server_cert", local.config.ldap_server_cert)
    ldap_instance                        = lookup(local.override[local.override_type], "ldap_instance", local.config.ldap_instance)
    scale_encryption_enabled             = lookup(local.override[local.override_type], "scale_encryption_enabled", local.config.scale_encryption_enabled)
    scale_encryption_type                = lookup(local.override[local.override_type], "scale_encryption_type", local.config.scale_encryption_type)
    gklm_instances                       = lookup(local.override[local.override_type], "gklm_instances", local.config.gklm_instances)
    key_protect_instance_id              = lookup(local.override[local.override_type], "key_protect_instance_id", local.config.key_protect_instance_id)
    storage_type                         = lookup(local.override[local.override_type], "storage_type", local.config.storage_type)
    colocate_protocol_instances          = lookup(local.override[local.override_type], "colocate_protocol_instances", local.config.colocate_protocol_instances)
    scale_encryption_admin_password      = lookup(local.override[local.override_type], "scale_encryption_admin_password", local.config.scale_encryption_admin_password)
    filesystem_config                    = lookup(local.override[local.override_type], "filesystem_config", local.config.filesystem_config)
    existing_bastion_instance_name       = lookup(local.override[local.override_type], "existing_bastion_instance_name", local.config.existing_bastion_instance_name)
    existing_bastion_instance_public_ip  = lookup(local.override[local.override_type], "existing_bastion_instance_public_ip", local.config.existing_bastion_instance_public_ip)
    existing_bastion_security_group_id   = lookup(local.override[local.override_type], "existing_bastion_security_group_id", local.config.existing_bastion_security_group_id)
    existing_bastion_ssh_private_key     = lookup(local.override[local.override_type], "existing_bastion_ssh_private_key", local.config.existing_bastion_ssh_private_key)
    bms_boot_drive_encryption            = lookup(local.override[local.override_type], "bms_boot_drive_encryption", local.config.bms_boot_drive_encryption)
    tie_breaker_baremetal_server_profile = lookup(local.override[local.override_type], "tie_breaker_baremetal_server_profile", local.config.tie_breaker_baremetal_server_profile)
    filesets_config                      = lookup(local.override[local.override_type], "filesets_config", local.config.filesets_config)
    login_security_group_name            = lookup(local.override[local.override_type], "login_security_group_name", local.config.login_security_group_name)
    storage_security_group_name          = lookup(local.override[local.override_type], "storage_security_group_name", local.config.storage_security_group_name)
    compute_security_group_name          = lookup(local.override[local.override_type], "compute_security_group_name", local.config.compute_security_group_name)
    client_security_group_name           = lookup(local.override[local.override_type], "client_security_group_name", local.config.client_security_group_name)
    gklm_security_group_name             = lookup(local.override[local.override_type], "gklm_security_group_name", local.config.gklm_security_group_name)
    ldap_security_group_name             = lookup(local.override[local.override_type], "ldap_security_group_name", local.config.ldap_security_group_name)
    login_subnet_id                      = lookup(local.override[local.override_type], "login_subnet_id", local.config.login_subnet_id)
    compute_subnet_id                    = lookup(local.override[local.override_type], "compute_subnet_id", local.config.compute_subnet_id)
    storage_subnet_id                    = lookup(local.override[local.override_type], "storage_subnet_id", local.config.storage_subnet_id)
    protocol_subnet_id                   = lookup(local.override[local.override_type], "protocol_subnet_id", local.config.protocol_subnet_id)
    client_subnet_id                     = lookup(local.override[local.override_type], "client_subnet_id", local.config.client_subnet_id)
    scale_management_vsi_profile         = lookup(local.override[local.override_type], "scale_management_vsi_profile", local.config.scale_management_vsi_profile)
    volume_storages                      = lookup(local.override[local.override_type], "volume_storages", local.config.volume_storages)
    enable_private_path_nlb              = lookup(local.override[local.override_type], "enable_private_path_nlb", local.config.enable_private_path_nlb)
    protocol_instance_eth1_mtu           = lookup(local.override[local.override_type], "protocol_instance_eth1_mtu", local.config.protocol_instance_eth1_mtu)
  }
}
