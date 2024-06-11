output "cloud_monitoring_access_key" {
  value       = var.cloud_monitoring_provision ? module.observability_instance.cloud_monitoring_access_key : null
  description = "IBM Cloud Monitoring access key for agents to use"
  sensitive   = true
}

output "cloud_monitoring_ingestion_url" {
  value       = var.cloud_monitoring_provision ? "ingest.${var.location}.monitoring.cloud.ibm.com" : null
  description = "IBM Cloud Monitoring ingestion url for agents to use"
}

output "log_analysis_ingestion_key" {
  value       = var.log_analysis_provision ? module.observability_instance.log_analysis_ingestion_key : null
  description = "Log Analysis ingest key for agents to use"
  sensitive   = true
}

output "cloud_monitoring_prws_key" {
  value       = var.cloud_monitoring_provision ? jsondecode(data.http.sysdig_prws_key.response_body).token.key : null
  description = "IBM Cloud Monitoring Prometheus Remote Write ingestion key"
  sensitive   = true
}

output "cloud_monitoring_prws_url" {
  value       = "https://ingest.prws.${var.location}.monitoring.cloud.ibm.com/prometheus/remote/write"
  description = "IBM Cloud Monitoring Prometheus Remote Write ingestion url"
}

output "cloud_monitoring_url" {
  value       = var.cloud_monitoring_provision ? "https://cloud.ibm.com/observe/embedded-view/monitoring/${module.observability_instance.cloud_monitoring_guid}" : null
  description = "IBM Cloud Monitoring URL"
}
