locals {
  schematics_inputs_path             = format("/tmp/.schematics/%s/solution_terraform.auto.tfvars.json", var.cluster_prefix)
  scheduler                          = var.scheduler == null ? "null" : var.scheduler
  ibm_customer_number                = var.ibm_customer_number == null ? "" : var.ibm_customer_number
  storage_security_group_id          = var.storage_security_group_id == null ? "" : var.storage_security_group_id
  zones                              = jsonencode(var.zones)
  list_ssh_keys                      = jsonencode(var.ssh_keys)
  list_storage_instances             = jsonencode(var.storage_instances)
  list_storage_servers               = jsonencode(var.storage_servers)
  list_management_instances          = jsonencode(var.management_instances)
  list_protocol_instances            = jsonencode(var.protocol_instances)
  list_compute_instances             = jsonencode(var.static_compute_instances)
  list_client_instances              = jsonencode(var.client_instances)
  remote_allowed_ips                 = jsonencode(var.remote_allowed_ips)
  list_storage_subnets               = jsonencode(length(var.storage_subnets) == 0 ? null : var.storage_subnets)
  list_protocol_subnets              = jsonencode(length(var.protocol_subnets) == 0 ? null : var.protocol_subnets)
  list_cluster_subnet_id             = jsonencode(length(var.cluster_subnet_id) == 0 ? null : var.cluster_subnet_id)
  list_client_subnets                = jsonencode(length(var.client_subnets) == 0 ? null : var.client_subnets)
  list_login_subnet_ids              = jsonencode(length(var.login_subnet_id) == 0 ? null : var.login_subnet_id)
  dns_domain_names                   = jsonencode(var.dns_domain_names)
  dynamic_compute_instances          = jsonencode(var.dynamic_compute_instances)
  kms_key_name                       = jsonencode(var.kms_key_name)
  kms_instance_name                  = jsonencode(var.kms_instance_name)
  key_management                     = jsonencode(var.key_management)
  boot_volume_encryption_key         = jsonencode(var.boot_volume_encryption_key)
  existing_kms_instance_guid         = jsonencode(var.existing_kms_instance_guid)
  dns_custom_resolver_id             = jsonencode(var.dns_custom_resolver_id != null ? (length(var.dns_custom_resolver_id) > 0 ? var.dns_custom_resolver_id : null) : var.dns_custom_resolver_id)
  dns_instance_id                    = jsonencode(var.dns_instance_id != null ? (length(var.dns_instance_id) > 0 ? var.dns_instance_id : null) : var.dns_instance_id)
  list_ldap_instances                = jsonencode(var.ldap_instance)
  ldap_server                        = jsonencode(var.ldap_server)
  ldap_basedns                       = jsonencode(var.ldap_basedns)
  list_ldap_ssh_keys                 = jsonencode(var.ldap_instance_key_pair)
  list_afm_instances                 = jsonencode(var.afm_instances)
  afm_cos_config_details             = jsonencode(var.afm_cos_config)
  list_gklm_ssh_keys                 = jsonencode(var.gklm_instance_key_pair)
  list_gklm_instances                = jsonencode(var.gklm_instances)
  scale_encryption_type              = jsonencode(var.scale_encryption_type)
  filesystem_config                  = jsonencode(var.filesystem_config)
  scale_encryption_admin_password    = jsonencode(var.scale_encryption_admin_password)
  custom_file_shares                 = jsonencode(var.custom_file_shares)
  resource_group_ids                 = jsonencode(var.resource_group_ids)
  existing_bastion_instance_name     = jsonencode(var.existing_bastion_instance_name == null ? null : var.existing_bastion_instance_name)
  existing_bastion_security_group_id = jsonencode(var.existing_bastion_security_group_id == null ? null : var.existing_bastion_security_group_id)
  login_instance                     = jsonencode(var.login_instance)

}
