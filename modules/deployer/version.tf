terraform {
  required_version = ">= 1.9.0"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">= 1.68.1, < 2.0.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2"
    }
  }
}
