terraform {
  required_version = ">= 1.3"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2"
    }
  }
}
