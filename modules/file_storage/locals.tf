locals {
  name   = "hpc"
  prefix = var.prefix
  tags   = [local.prefix, local.name]
}
