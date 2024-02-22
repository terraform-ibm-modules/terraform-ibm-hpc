################################################################################
# database/mysql/main.tf - Creating a MySQL database
################################################################################
# Copyright 2023 IBM
#
# Licensed under the MIT License. See the LICENSE file for details.
#
# Maintainer: Salvatore D'Angelo
################################################################################

resource "ibm_database" "itself" {
  resource_group_id = var.resource_group_id
  name              = var.name
  service           = "databases-for-mysql"
  plan              = var.plan
  location          = var.region
  adminpassword     = var.adminpassword
  service_endpoints = var.service_endpoints

  group {
    group_id = "member"
    members {
      allocation_count = var.members
    }
    memory {
      allocation_mb = var.memory
    }
    disk {
      allocation_mb = var.disks
    }
    cpu {
      allocation_count = var.vcpu
    }
  }
}
