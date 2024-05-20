terraform {
  required_version = ">= 1.3, < 1.7"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.64.2"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.4.2"
    }
  }
}
