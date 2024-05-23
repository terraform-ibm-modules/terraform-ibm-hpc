###############################################################
# Outputs
###############################################################

output "scc_crn" {
  value       = var.scc_provision ? module.create_scc_instance.crn : null
  description = "The CRN of the SCC instance created by this module"
  sensitive   = true
}

output "scc_en_crn" {
  description = "The CRN of the event notification instance created in this module"
  value       = var.scc_provision ? module.event_notification.crn : null
}
