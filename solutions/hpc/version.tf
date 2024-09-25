terraform {
  required_version = ">= 1.3"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.69.2"
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
