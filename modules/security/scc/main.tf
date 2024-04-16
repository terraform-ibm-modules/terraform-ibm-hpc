# This module requires additional logdna provider configuration blocks
locals {
  scc_region  = var.location != "" ? var.location : "us-south"
  scc_scope   = [{
    environment = var.scc_scope_environment
    properties = [
      {
        name  = "scope_id"
        value = data.ibm_resource_group.rg.id
      },
      {
        name  = "scope_type"
        value = "account.resource_group"
      }
    ]
  }]
}

module "cos" {
  source                 = "terraform-ibm-modules/cos/ibm"
  version                = "7.3.2"
  cos_instance_name      = "${var.prefix}-scc-cos"
  kms_encryption_enabled = false
  retention_enabled      = false
  resource_group_id      = data.ibm_resource_group.rg.id
  bucket_name            = "${var.prefix}-scc-cb"
}

module "event_notification" {
  source            = "terraform-ibm-modules/event-notifications/ibm"
  version           = "1.0.4"
  resource_group_id = data.ibm_resource_group.rg.id
  name              = "${var.prefix}-scc-event_notification"
  plan              = var.event_notification_plan
  service_endpoints = var.event_notification_service-endpoints
  region            = local.scc_region
  tags              = var.tags
}

module "create_scc_instance" {
  source                            = "terraform-ibm-modules/scc/ibm"
  version                           = "1.1.0" # Replace "X.X.X" with a release version to lock into a specific release
  instance_name                     = "${var.prefix}-scc-instance"
  plan                              = var.scc_plan
  region                            = local.scc_region
  resource_group_id                 = data.ibm_resource_group.rg.id
  cos_bucket                        = module.cos.bucket_name
  cos_instance_crn                  = module.cos.cos_instance_id
  en_instance_crn                   = module.event_notification.crn
  skip_cos_iam_authorization_policy = false
  resource_tags                     = var.tags
}

module "create_profile_attachment" {
  count                  = var.scc_profile == null || var.scc_profile == "" ? 0 : 1
  source                 = "terraform-ibm-modules/scc/ibm//modules/attachment"
  version                = "1.2.0"
  profile_id             = var.scc_profile # data.ibm_scc_profile.scc_profile.id
  scc_instance_id        = module.create_scc_instance.guid
  attachment_name        = "${var.prefix}-scc-attachment"
  attachment_description = var.scc_attachment_description
  attachment_schedule    = var.scc_attachment_schedule
  scope                  = local.scc_scope
}
