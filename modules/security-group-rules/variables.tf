
variable "add_ibm_cloud_internal_rules" {
  description = "Add IBM cloud Internal rules to the provided security group rules"
  type        = bool
  default     = false
}

variable "sg_id" {
  description = "ID of the VPC to create security group. Only required if 'existing_security_group_name' is null"
  type        = string
  default     = null
}

##############################################################################
# Rule Variables
##############################################################################

variable "security_group_rules" {
  description = "A list of security group rules to be added to the default vpc security group"
  type = list(
    object({
      name      = string
      direction = optional(string, "inbound")
      remote    = string
      tcp = optional(
        object({
          port_max = optional(number)
          port_min = optional(number)
        })
      )
      udp = optional(
        object({
          port_max = optional(number)
          port_min = optional(number)
        })
      )
      icmp = optional(
        object({
          type = optional(number)
          code = optional(number)
        })
      )
    })
  )
  default = []

  validation {
    error_message = "Security group rule direction can only be `inbound` or `outbound`."
    condition = (var.security_group_rules == null || length(var.security_group_rules) == 0) ? true : length(distinct(
      flatten([
        # Check through rules
        for rule in var.security_group_rules :
        # Return false if direction is not valid
        false if !contains(["inbound", "outbound"], rule.direction)
      ])
    )) == 0
  }

  validation {
    error_message = "Security group rule names must match the regex pattern ^([a-z]|[a-z][-a-z0-9_]*[a-z0-9])$."
    condition = (var.security_group_rules == null || length(var.security_group_rules) == 0) ? true : length(distinct(
      flatten([
        # Check through rules
        for rule in var.security_group_rules :
        # Return false if direction is not valid
        false if !can(regex("^([a-z]|[a-z][-a-z0-9_]*[a-z0-9])$", rule.name))
      ])
    )) == 0
  }

  validation {
    error_message = "Security group rules can only have one of `icmp`, `udp`, or `tcp`."
    condition = (var.security_group_rules == null || length(var.security_group_rules) == 0) ? true : length(distinct(
      # Get flat list of results
      flatten([
        # Check through rules
        for rule in var.security_group_rules :
        # Return true if there is more than one of `icmp`, `udp`, or `tcp`
        true if length(
          [
            for type in ["tcp", "udp", "icmp"] :
            true if rule[type] != null
          ]
        ) > 1
      ])
    )) == 0 # Checks for length. If all fields all correct, array will be empty
  }
}

##############################################################################
