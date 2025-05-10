# This module requires additional logdna provider configuration blocks
locals {
  scc_region = var.location != "" ? var.location : "us-south"
  scc_scope = [{
    environment = var.scc_scope_environment
    properties = [
      {
        name  = "scope_id"
        value = var.rg
      },
      {
        name  = "scope_type"
        value = "account.resource_group"
      }
    ]
  }]
}

module "event_notification" {
  source            = "terraform-ibm-modules/event-notifications/ibm"
  version           = "1.20.2"
  resource_group_id = var.rg
  name              = "${var.prefix}-scc-event_notification"
  plan              = var.event_notification_plan
  service_endpoints = var.event_notification_service_endpoints
  region            = local.scc_region
  tags              = var.tags
}

module "create_scc_instance" {
  source                            = "terraform-ibm-modules/scc/ibm"
  version                           = "1.11.2"
  instance_name                     = "${var.prefix}-scc-instance"
  plan                              = var.scc_plan
  region                            = local.scc_region
  resource_group_id                 = var.rg
  resource_tags                     = var.tags
  cos_bucket                        = var.cos_bucket
  cos_instance_crn                  = var.cos_instance_crn
  en_instance_crn                   = module.event_notification.crn
  skip_cos_iam_authorization_policy = false
  attach_wp_to_scc_instance         = false
  skip_scc_wp_auth_policy           = true
  wp_instance_crn                   = null
  en_source_name                    = var.en_source_name
  en_source_description             = var.en_source_description
}

module "create_profile_attachment" {
  count                  = var.scc_profile == null || var.scc_profile == "" ? 0 : 1
  source                 = "terraform-ibm-modules/scc/ibm//modules/attachment"
  version                = "1.11.2"
  profile_name           = var.scc_profile
  scc_instance_id        = module.create_scc_instance.guid
  attachment_name        = "${var.prefix}-scc-attachment"
  attachment_description = var.scc_attachment_description
  attachment_schedule    = var.scc_attachment_schedule
  scope                  = local.scc_scope
}
