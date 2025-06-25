variable "region" {
  description = "IBM Cloud region where all resources will be deployed"
  type        = string
  default     = "us-south"
}

variable "resource_group_name" {
  description = "The resource group ID where resources will be provisioned."
  type        = string
}

variable "prefix" {
  description = "The name to give the SCC Workload Protection instance that will be provisioned by this module."
  type        = string
}

variable "sccwp_service_plan" {
  description = "IBM service pricing plan."
  type        = string
  default     = "free-trial"
  validation {
    error_message = "Plan for SCC Workload Protection instances can only be `free-trial` or `graduated-tier`."
    condition = contains(
      ["free-trial", "graduated-tier"],
      var.sccwp_service_plan
    )
  }
}

variable "app_config_plan" {
  description = "IBM service pricing plan."
  type        = string
  default     = "basic"
  validation {
    error_message = "Plan for SCC Workload Protection instances can only be `free-trial` or `graduated-tier`."
    condition = contains(
      ["basic", "lite", "Standard", "Enterprise"],
      var.app_config_plan
    )
  }
}

variable "resource_tags" {
  type        = list(string)
  description = "Optional list of tags to be added to created SCC WP instance."
  default     = []
}

variable "access_tags" {
  type        = list(string)
  description = "A list of access tags to apply to the SCC WP instance created by the module. For more information, see https://cloud.ibm.com/docs/account?topic=account-access-tags-tutorial."
  default     = []

  validation {
    condition = alltrue([
      for tag in var.access_tags : can(regex("[\\w\\-_\\.]+:[\\w\\-_\\.]+", tag)) && length(tag) <= 128
    ])
    error_message = "Tags must match the regular expression \"[\\w\\-_\\.]+:[\\w\\-_\\.]+\", see https://cloud.ibm.com/docs/account?topic=account-tag&interface=ui#limits for more details"
  }
}

variable "resource_key_name" {
  type        = string
  description = "The name to give the IBM Cloud SCC WP resource key."
  default     = "SCCWPManagerKey"
}

variable "resource_key_tags" {
  type        = list(string)
  description = "Tags associated with the IBM Cloud SCC WP resource key."
  default     = []
}

variable "cspm_enabled" {
  description = "Enable Cloud Security Posture Management (CSPM) for the Workload Protection instance. This will create a trusted profile associated with the SCC Workload Protection instance that has viewer / reader access to the App Config service and viewer access to the Enterprise service. [Learn more](https://cloud.ibm.com/docs/workload-protection?topic=workload-protection-about)."
  type        = bool
  default     = false
  nullable    = false
}

#variable "app_config_crn" {
#  description = "The CRN of an existing App Config instance to use with the SCC Workload Protection instance. Required if `cspm_enabled` is true. NOTE: Ensure the App Config instance has configuration aggregator enabled."
#  type        = string
#  default     = null
#  validation {
#    condition     = var.cspm_enabled ? var.app_config_crn != null : true
#    error_message = "Cannot be `null` if CSPM is enabled."
#  }
#  validation {
#    condition = anytrue([
#      can(regex("^crn:(.*:){3}apprapp:(.*:){2}[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}::$", var.app_config_crn)),
#      var.app_config_crn == null,
#    ])
#    error_message = "The provided CRN is not a valid App Config CRN."
#  }
#}

variable "scc_workload_protection_trusted_profile_name" {
  description = "The name to give the trusted profile that is created by this module if `cspm_enabled` is `true. Must begin with a letter."
  type        = string
  default     = "workload-protection-trusted-profile"
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9\\-_\\.]+$", var.scc_workload_protection_trusted_profile_name))
    error_message = "The trusted profile name must begin with a letter and can only contain letters, numbers, hyphens, underscores, and periods."
  }
  validation {
    condition     = !(var.cspm_enabled && var.scc_workload_protection_trusted_profile_name == null)
    error_message = "Cannot be `null` if `cspm_enabled` is `true`."
  }
}

variable "cbr_rules" {
  type = list(object({
    description = string
    account_id  = string
    tags = optional(list(object({
      name  = string
      value = string
    })), [])
    rule_contexts = list(object({
      attributes = optional(list(object({
        name  = string
        value = string
    }))) }))
    enforcement_mode = string
  }))
  description = "The list of context-based restriction rules to create."
  default     = []
  # Validation happens in the rule module
}

variable "enable_deployer" {
  type        = bool
  default     = true
  description = "Deployer should be only used for better deployment performance"
}

variable "sccwp_enable" {
  type        = bool
  default     = true
  description = "Flag to enable SCC instance creation. If true, an instance of SCC (Security and Compliance Center) will be created."
}
