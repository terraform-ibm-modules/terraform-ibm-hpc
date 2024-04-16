data "ibm_resource_group" "rg" {
  name = var.rg
}

data "ibm_iam_auth_token" "tokendata" {}

data "http" "sysdig_prws_key" {
  url = "https://${var.location}.monitoring.cloud.ibm.com/api/token"

  # Optional request headers
  request_headers = {
    Accept        = "application/json"
    Authorization = data.ibm_iam_auth_token.tokendata.iam_access_token
    IBMInstanceID = var.cloud_monitoring_provision ? module.observability_instance.cloud_monitoring_guid : ""
  }
}
