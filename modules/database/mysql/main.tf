################################################################################
# database/mysql/main.tf - Creating a MySQL database
################################################################################
# Copyright 2023 IBM
#
# Licensed under the MIT License. See the LICENSE file for details.
#
# Maintainer: Salvatore D'Angelo
################################################################################

module "db" {
  source             = "terraform-ibm-modules/icd-mysql/ibm"
  version            = "1.11.11"
  resource_group_id  = var.resource_group_id
  name               = var.name
  region             = var.region
  service_endpoints  = var.service_endpoints
  mysql_version      = var.mysql_version
  admin_pass         = var.admin_password
  members            = var.members
  member_memory_mb   = var.memory
  member_disk_mb     = var.disks
  member_cpu_count   = var.vcpu
  member_host_flavor = var.host_flavour
}
