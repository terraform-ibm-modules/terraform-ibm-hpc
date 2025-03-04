terraform {
  required_version = ">= 1.9.0"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">= 1.56.2"
    }
    time = {
      source  = "hashicorp/time"
      version = ">=0.11.2"
    }
  }
}
