# define variables
locals {
  hosts = var.enable_bootstrap ? [] : var.hosts
}