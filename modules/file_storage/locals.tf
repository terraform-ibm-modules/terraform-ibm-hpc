locals {
  name   = "lsf"
  prefix = var.prefix
  tags   = [local.prefix, local.name]
}
