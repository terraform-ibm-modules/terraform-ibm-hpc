output "app_config_crn" {
  description = "app config crn"
  value       = length(module.app_config) > 0 ? module.app_config[0].app_config_crn : null
}

output "sccwp_api_endpoint" {
  description = "The SCC Workload Protection API endpoint, dynamically formatted for the Sysdig agent dragent.yaml (stripping https:// and /api)."
  value       = length(module.scc_workload_protection) > 0 ? replace(replace(module.scc_workload_protection[0].api_endpoint, "https://", ""), "/api", "") : null
}

output "sccwp_access_key" {
  description = "The Access Key for the SCC Workload Protection instance."
  value       = length(module.scc_workload_protection) > 0 ? module.scc_workload_protection[0].access_key : null
  sensitive   = true
}

output "sccwp_ingestion_endpoint" {
  description = "The ingestion collector endpoint for the SCC Workload Protection instance."
  value       = length(module.scc_workload_protection) > 0 ? module.scc_workload_protection[0].ingestion_endpoint : null
}
