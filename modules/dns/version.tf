terraform {
  required_version = ">= 1.3, < 1.7"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">= 1.56.2"
    }
  }
}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
}
