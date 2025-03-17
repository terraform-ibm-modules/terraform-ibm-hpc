terraform {
  required_version = ">= 1.3"
  # Use "greater than or equal to" range for root level modules
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">= 1.68.1, < 2.0.0"
    }
  }
}