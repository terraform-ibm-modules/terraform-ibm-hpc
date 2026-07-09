variable "key_protect_instance_id" {
  type        = string
  default     = null
  description = "An existing Key Protect instance used for filesystem encryption"
}

variable "resource_prefix" {
  type        = string
  default     = "scale"
  description = "A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
}

variable "vpc_region" {
  type        = string
  default     = null
  description = "vpc region"
}

variable "scale_config_path" {
  type        = string
  default     = "/opt/IBM/ibm-spectrumscale-cloud-deploy"
  description = "Path to clone github.com/IBM/ibm-spectrum-scale-install-infra."
}

variable "vpc_storage_cluster_dns_domain" {
  type        = string
  default     = "ldap.com"
  description = "Base domain for the LDAP Server"
}
