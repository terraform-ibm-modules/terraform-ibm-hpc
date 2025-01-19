output "cloud_monitoring_access_key" {
  value       = var.cloud_monitoring_provision ? module.observability_instance.cloud_monitoring_access_key : null
  description = "IBM Cloud Monitoring access key for agents to use"
  sensitive   = true
}

output "cloud_monitoring_ingestion_url" {
  value       = var.cloud_monitoring_provision ? "ingest.${var.location}.monitoring.cloud.ibm.com" : null
  description = "IBM Cloud Monitoring ingestion url for agents to use"
}

output "cloud_monitoring_prws_key" {
  value       = var.cloud_monitoring_provision ? jsondecode(data.http.sysdig_prws_key[0].response_body).token.key : null
  description = "IBM Cloud Monitoring Prometheus Remote Write ingestion key"
  sensitive   = true
}

output "cloud_monitoring_prws_url" {
  value       = "https://ingest.prws.${var.location}.monitoring.cloud.ibm.com/prometheus/remote/write"
  description = "IBM Cloud Monitoring Prometheus Remote Write ingestion url"
}

output "cloud_logs_ingress_endpoint" {
  value       = var.cloud_logs_provision ? module.observability_instance.cloud_logs_ingress_endpoint : null
  description = "The public ingress endpoint of the provisioned Cloud Logs instance."
}

output "cloud_logs_ingress_private_endpoint" {
  value       = var.cloud_logs_provision ? module.observability_instance.cloud_logs_ingress_private_endpoint : ""
  description = "The private ingress endpoint of the provisioned Cloud Logs instance."
}

output "cloud_monitoring_url" {
  value       = var.cloud_monitoring_provision ? "https://cloud.ibm.com/observe/embedded-view/monitoring/${module.observability_instance.cloud_monitoring_guid}" : null
  description = "IBM Cloud Monitoring URL"
}

output "cloud_logs_url" {
  value       = var.cloud_logs_provision ? "https://dashboard.${var.location}.logs.cloud.ibm.com/${module.observability_instance.cloud_logs_guid}" : null
  description = "IBM Cloud Logs URL"
}
