locals {
  # Region and Zone calculations
  region = join("-", slice(split("-", var.zone), 0, 2))
}

locals {
  name           = "hpc"
  prefix         = var.prefix
  tags           = [local.prefix, local.name]
}