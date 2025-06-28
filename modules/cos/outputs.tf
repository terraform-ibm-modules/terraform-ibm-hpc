output "afm_cos_bucket_details" {
  value       = concat(local.afm_cos_bucket_details_1, local.afm_cos_bucket_details_2, local.afm_cos_bucket_details_3, local.afm_cos_bucket_details_4, local.afm_cos_bucket_details_5)
  description = "AFM cos bucket details"
}

output "afm_config_details" {
  value       = concat(local.afm_config_details_1, local.afm_config_details_2, local.afm_config_details_3, local.afm_config_details_4, local.afm_config_details_5)
  description = "AFM configuration details"
}
