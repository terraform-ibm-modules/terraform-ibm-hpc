# define variables
locals {
  dns_records = var.enable_bootstrap ? [] : var.dns_records
}