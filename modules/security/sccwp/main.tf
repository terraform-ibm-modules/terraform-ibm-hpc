data "ibm_iam_auth_token" "auth_token" {}

provider "restapi" {
  # see https://cloud.ibm.com/apidocs/resource-controller/resource-controller#endpoint-url for full list of available resource controller endpoints
  uri = "https://resource-controller.cloud.ibm.com"
  headers = {
    Authorization = data.ibm_iam_auth_token.auth_token.iam_access_token
  }
  write_returns_object = true
}

module "app_config" {
  count                                  = var.enable_deployer == false && var.sccwp_enable && var.cspm_enabled ? 1 : 0
  source                                 = "terraform-ibm-modules/app-configuration/ibm"
  version                                = "1.8.2"
  region                                 = var.region
  resource_group_id                      = data.ibm_resource_group.existing_resource_group[0].id
  app_config_plan                        = var.app_config_plan
  app_config_name                        = "${var.prefix}-app-config"
  app_config_tags                        = var.resource_tags
  enable_config_aggregator               = true
  config_aggregator_trusted_profile_name = "${var.prefix}-app-config-tp"
}

module "scc-workload-protection" {
  count                                        = var.enable_deployer == false && var.sccwp_enable ? 1 : 0
  source                                       = "terraform-ibm-modules/scc-workload-protection/ibm"
  version                                      = "1.10.0"
  region                                       = var.region
  name                                         = var.prefix
  resource_group_id                            = data.ibm_resource_group.existing_resource_group[0].id
  scc_wp_service_plan                          = var.sccwp_service_plan
  resource_tags                                = var.resource_tags
  cspm_enabled                                 = var.cspm_enabled
  app_config_crn                               = var.cspm_enabled && length(module.app_config) > 0 ? module.app_config[0].app_config_crn : null
  scc_workload_protection_trusted_profile_name = var.cspm_enabled == true ? "${var.prefix}-wp-tp" : "workload-protection-trusted-profile"
}
