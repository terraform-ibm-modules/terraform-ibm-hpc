terraform {
  required_version = ">= 1.9.0"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.79.2"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.5.0"
    }
  }
}
