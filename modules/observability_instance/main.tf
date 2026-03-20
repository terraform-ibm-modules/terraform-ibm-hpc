# This module requires additional logdna provider configuration blocks
locals {
  cloud_monitoring_instance_name = var.cloud_monitoring_instance_name
  # logs_instance_endpoint         = "https://api.${var.location}.logging.cloud.ibm.com"
}


module "cloud_logs" {
  source                      = "terraform-ibm-modules/cloud-logs/ibm"
  version                     = "1.12.2"
  count                       = (var.cloud_logs_provision || var.cloud_logs_as_atracker_target) ? 1 : 0
  resource_group_id           = var.rg
  region                      = var.location
  instance_name               = var.cloud_logs_instance_name
  plan                        = "standard"
  resource_tags               = var.tags
  retention_period            = var.cloud_logs_retention_period
  logs_routing_tenant_regions = var.enable_platform_logs ? [var.location] : []
  data_storage = {
    # logs and metrics buckets must be different
    logs_data = {
      enabled         = true
      bucket_crn      = var.cloud_logs_data_bucket != null ? var.cloud_logs_data_bucket["bucket_crn"] : ""
      bucket_endpoint = var.cloud_logs_data_bucket != null ? var.cloud_logs_data_bucket["bucket_endpoint"] : ""
    },
    metrics_data = {
      enabled         = true
      bucket_crn      = var.cloud_metrics_data_bucket != null ? var.cloud_metrics_data_bucket["bucket_crn"] : ""
      bucket_endpoint = var.cloud_metrics_data_bucket != null ? var.cloud_metrics_data_bucket["bucket_endpoint"] : ""
    }
  }
}

module "cloud_monitoring" {
  source                  = "terraform-ibm-modules/cloud-monitoring/ibm"
  version                 = "1.14.3"
  count                   = var.cloud_monitoring_provision ? 1 : 0
  region                  = var.location
  resource_group_id       = var.rg
  instance_name           = local.cloud_monitoring_instance_name
  plan                    = var.observability_monitoring_plan
  resource_tags           = var.tags
  enable_platform_metrics = false

}

module "activity_tracker" {
  source  = "terraform-ibm-modules/activity-tracker/ibm"
  version = "1.6.13"

  # Cloud Logs target
  cloud_logs_targets = var.cloud_logs_as_atracker_target ? [
    {
      instance_id   = module.cloud_logs[0].crn
      target_region = var.location
      target_name   = "${var.cluster_prefix}-atracker-target"
    }
  ] : []

  # AT Event routing route
  activity_tracker_routes = var.cloud_logs_as_atracker_target ? [
    {
      locations  = ["*", "global"]
      target_ids = [module.activity_tracker.activity_tracker_targets["${var.cluster_prefix}-atracker-target"].id]
      route_name = "${var.cluster_prefix}-atracker-route"
    }
  ] : []
}

# IBM Cloud Metrics Routing
module "metric_router" {
  source  = "terraform-ibm-modules/cloud-monitoring/ibm//modules/metrics_routing"
  version = "1.14.3" # Replace "X.Y.Z" with a release version to lock into a specific release
  count   = (var.enable_metrics_routing && var.cloud_monitoring_provision) ? 1 : 0
  metrics_router_targets = [
    {
      # ID of the Cloud Monitoring instance
      destination_crn = module.cloud_monitoring[0].crn
      target_region   = var.location
      target_name     = "${var.cluster_prefix}-metrics-routing-target"
    }
  ]

  metrics_router_routes = [
    {
      name = "${var.cluster_prefix}-metrics-routing-route"
      rules = [
        {
          action = "send"
          targets = [{
            id = module.metric_router[0].metrics_router_targets["${var.cluster_prefix}-metrics-routing-target"].id
          }]
          inclusion_filters = [{
            operand  = "location"
            operator = "is"
            values   = [var.location]
          }]
        }
      ]
    }
  ]
}

# Cloud Logs
moved {
  from = module.observability_instance.module.cloud_logs[0]
  to   = module.cloud_logs[0]
}

# Cloud Monitoring
moved {
  from = module.observability_instance.module.cloud_monitoring[0].ibm_resource_instance.cloud_monitoring[0]
  to   = module.cloud_monitoring[0].ibm_resource_instance.cloud_monitoring
}

moved {
  from = module.observability_instance.module.cloud_monitoring[0].ibm_resource_key.resource_key[0]
  to   = module.cloud_monitoring[0].ibm_resource_key.resource_key
}

moved {
  from = module.observability_instance.module.cloud_monitoring[0].ibm_resource_tag.cloud_monitoring_tag
  to   = module.cloud_monitoring[0].ibm_resource_tag.cloud_monitoring_tag
}

# Metrics Routing
moved {
  from = module.observability_instance.module.metric_routing
  to   = module.metrics_router[0]
}

# Activity Tracker
moved {
  from = module.observability_instance.module.activity_tracker
  to   = module.activity_tracker
}
