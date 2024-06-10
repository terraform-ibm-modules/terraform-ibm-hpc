terraform {
  required_version = ">= 1.3"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">= 1.56.2"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2"
    }
  }
}
