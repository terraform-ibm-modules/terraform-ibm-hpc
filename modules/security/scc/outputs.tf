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

output "scc_cos_instance_id" {
  description = "The COS instance ID created in this module"
  value       = var.scc_provision ? module.cos.cos_instance_id : null
}

output "scc_cos_bucket" {
  description = "The COS bucket created in this module"
  value       = var.scc_provision ? module.cos.bucket_name : null
}
