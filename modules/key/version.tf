terraform {
  required_version = ">= 1.3, < 1.7"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4"
    }
  }
}
