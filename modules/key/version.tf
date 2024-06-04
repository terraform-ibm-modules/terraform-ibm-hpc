terraform {
  required_version = ">= 1.3, < 1.7"
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4"
    }
  }
}
