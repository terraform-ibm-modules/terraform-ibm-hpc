terraform {
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
    }
  }
}

variable "group" {}
variable "direction" {}
variable "remote" {}

resource "ibm_is_security_group_rule" "itself" {
  count     = length(var.remote)
  group     = var.group
  direction = var.direction
  remote    = var.remote[count.index]
  tcp {
    port_min = 443
    port_max = 443
  }
}
