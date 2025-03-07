data "ibm_iam_auth_token" "tokendata" {}

data "http" "sysdig_prws_key" {
  count = var.cloud_monitoring_provision ? 1 : 0
  url   = "https://${var.location}.monitoring.cloud.ibm.com/api/token"

  # Optional request headers
  request_headers = {
    Accept        = "application/json"
    Authorization = sensitive(data.ibm_iam_auth_token.tokendata.iam_access_token) # <--- Wrap this
    IBMInstanceID = var.cloud_monitoring_provision ? module.observability_instance.cloud_monitoring_guid : ""
  }
}
