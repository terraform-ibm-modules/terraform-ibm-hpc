terraform {
  required_version = ">= 1.9.0"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">= 1.56.2"
    }
    logdna = {
      source                = "logdna/logdna"
      version               = ">= 1.14.2"
      configuration_aliases = [logdna.ats, logdna.sts, logdna.at, logdna.ld]
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 2.0.0"
    }
  }
}
