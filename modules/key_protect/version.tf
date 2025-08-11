##############################################################################
# Terraform Providers
##############################################################################

terraform {
  required_version = ">= 1.9.0"
  # Use "greater than or equal to" range for root level modules
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">= 1.68.1, < 2.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
  }
}
