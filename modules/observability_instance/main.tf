# This module requires additional logdna provider configuration blocks
locals {
  activity_tracker_instance_name = var.activity_tracker_instance_name
  log_analysis_instance_name     = var.log_analysis_instance_name
  cloud_monitoring_instance_name = var.cloud_monitoring_instance_name

  logs_instance_endpoint = "https://api.${var.location}.logging.cloud.ibm.com"
}

module "observability_instance" {
  # Replace "master" with a GIT release version to lock into a specific release
  source  = "terraform-ibm-modules/observability-instances/ibm"
  version = "2.19.1"
  providers = {
    logdna.at = logdna.at
    logdna.ld = logdna.ld
  }
  region            = var.location
  ibmcloud_api_key  = var.ibmcloud_api_key
  resource_group_id = var.rg

  # Log Analysis
  log_analysis_provision     = var.log_analysis_provision
  log_analysis_instance_name = local.log_analysis_instance_name
  log_analysis_plan          = var.log_analysis_plan
  log_analysis_tags          = var.tags
  # IBM Cloud Monitoring
  cloud_monitoring_provision     = var.cloud_monitoring_provision
  cloud_monitoring_instance_name = local.cloud_monitoring_instance_name
  cloud_monitoring_plan          = var.observability_monitoring_plan
  cloud_monitoring_tags          = var.tags
  # Activity Tracker
  activity_tracker_plan          = var.activity_tracker_plan
  activity_tracker_instance_name = local.activity_tracker_instance_name
  activity_tracker_provision     = var.activity_tracker_provision
  activity_tracker_tags          = var.tags
  /*
  # Event Routing
  activity_tracker_routes            = var.activity_tracker_routes
  cos_targets                        = var.cos_targets
  eventstreams_targets               = var.eventstreams_targets
  log_analysis_targets               = var.log_analysis_targets
  global_event_routing_settings      = var.global_event_routing_settings
  */
  log_analysis_enable_archive     = var.log_analysis_enable_archive
  activity_tracker_enable_archive = var.activity_tracker_enable_archive
  enable_platform_logs            = var.enable_platform_logs
  enable_platform_metrics         = var.enable_platform_metrics
}
