terraform {
  required_version = ">= 1.9.0"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.71.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.3"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.4.5"
    }
  }
}
