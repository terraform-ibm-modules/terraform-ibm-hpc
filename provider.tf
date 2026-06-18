provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = local.region
}

data "ibm_iam_auth_token" "auth_token" {}

provider "restapi" {
  uri = "https://resource-controller.cloud.ibm.com"
  headers = {
    Authorization = data.ibm_iam_auth_token.auth_token.iam_access_token
  }
  write_returns_object = true
}
