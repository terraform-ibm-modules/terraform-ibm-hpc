terraform {
  required_version = ">= 1.3.0, <1.6.0"
  # If your module requires any terraform providers, uncomment the "required_providers" section below and add all required providers.
  # Each required provider's version should be a flexible range to future proof the module's usage with upcoming minor and patch versions.

  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">= 1.56.2"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 2.0.0"
    }
  }
}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = local.region_name
}
