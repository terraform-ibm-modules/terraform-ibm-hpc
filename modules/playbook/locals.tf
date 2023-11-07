# define variables
locals {
  inventory_path = var.enable_bootstrap ? null : var.inventory_path
}