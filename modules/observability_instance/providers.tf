provider "logdna" {
  alias      = "ats"
  servicekey = module.observability_instance[0].activity_tracker_ats_resource_key != null ? module.observability_instance[0].activity_tracker_ats_resource_key : ""
  url        = local.logs_instance_endpoint
}

provider "logdna" {
  alias      = "sts"
  servicekey = module.observability_instance[0].log_analysis_sts_resource_key != null ? module.observability_instance[0].log_analysis_sts_resource_key : ""
  url        = local.logs_instance_endpoint
}

provider "logdna" {
  alias      = "at"
  servicekey = module.observability_instance[0].activity_tracker_resource_key != null ? module.observability_instance[0].activity_tracker_resource_key : ""
  url        = local.logs_instance_endpoint
}

provider "logdna" {
  alias      = "ld"
  servicekey = module.observability_instance[0].log_analysis_resource_key != null ? module.observability_instance[0].log_analysis_resource_key : ""
  url        = local.logs_instance_endpoint
}
