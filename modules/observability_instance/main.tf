# This module requires additional logdna provider configuration blocks
locals {
  cloud_monitoring_instance_name = var.cloud_monitoring_instance_name
  logs_instance_endpoint         = "https://api.${var.location}.logging.cloud.ibm.com"
}

module "observability_instance" {
  # Replace "master" with a GIT release version to lock into a specific release
  source            = "terraform-ibm-modules/observability-instances/ibm"
  version           = "3.5.3"
  region            = var.location
  resource_group_id = var.rg

  # IBM Cloud Logs
  cloud_logs_instance_name    = var.cloud_logs_instance_name
  cloud_logs_plan             = "standard"
  cloud_logs_provision        = var.cloud_logs_provision || var.cloud_logs_as_atracker_target
  cloud_logs_retention_period = var.cloud_logs_retention_period
  cloud_logs_tags             = var.tags
  cloud_logs_data_storage = {
    # logs and metrics buckets must be different
    logs_data = {
      enabled         = true
      bucket_crn      = var.cloud_logs_data_bucket != null ? var.cloud_logs_data_bucket["crn"] : ""
      bucket_endpoint = var.cloud_logs_data_bucket != null ? var.cloud_logs_data_bucket["s3_endpoint_direct"] : ""
    },
    metrics_data = {
      enabled         = true
      bucket_crn      = var.cloud_metrics_data_bucket != null ? var.cloud_metrics_data_bucket["crn"] : ""
      bucket_endpoint = var.cloud_metrics_data_bucket != null ? var.cloud_metrics_data_bucket["s3_endpoint_direct"] : ""
    }
  }
  activity_tracker_routes = var.cloud_logs_as_atracker_target ? [
    {
      locations  = ["*", "global"]
      target_ids = [module.observability_instance.activity_tracker_targets["${var.cluster_prefix}-atracker-target"].id]
      route_name = "${var.cluster_prefix}-atracker-route"
    }
  ] : []
  at_cloud_logs_targets = var.cloud_logs_as_atracker_target ? [
    {
      instance_id   = module.observability_instance.cloud_logs_crn
      target_region = var.location
      target_name   = "${var.cluster_prefix}-atracker-target"
    }
  ] : []
  # IBM Cloud Monitoring
  cloud_monitoring_provision     = var.cloud_monitoring_provision
  cloud_monitoring_instance_name = local.cloud_monitoring_instance_name
  cloud_monitoring_plan          = var.observability_monitoring_plan
  cloud_monitoring_tags          = var.tags

  enable_platform_logs    = var.enable_platform_logs
  enable_platform_metrics = false
  metrics_router_targets = (var.enable_metrics_routing && var.cloud_monitoring_provision) ? [
    {
      destination_crn = module.observability_instance.cloud_monitoring_crn
      target_region   = var.location
      target_name     = "${var.cluster_prefix}-metrics-routing-target"
    }
  ] : []
  metrics_router_routes = (var.enable_metrics_routing && var.cloud_monitoring_provision) ? [
    {
      name = "${var.cluster_prefix}-metrics-routing-route"
      rules = [
        {
          action = "send"
          targets = [{
            id = module.observability_instance.metrics_router_targets["${var.cluster_prefix}-metrics-routing-target"].id
          }]
          inclusion_filters = [{
            operand  = "location"
            operator = "is"
            values   = [var.location]
          }]
        }
      ]
    }
  ] : []
}
