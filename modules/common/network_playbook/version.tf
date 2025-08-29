##############################################################################
# Terraform Providers
##############################################################################

terraform {
  required_version = ">= 1.3"
  # Use "greater than or equal to" range for root level modules
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
  }
}
