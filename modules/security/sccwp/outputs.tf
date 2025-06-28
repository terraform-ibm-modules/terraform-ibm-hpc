output "app_config_crn" {
  description = "app config crn"
  value       = length(module.app_config) > 0 ? module.app_config[0].app_config_crn : null
}
