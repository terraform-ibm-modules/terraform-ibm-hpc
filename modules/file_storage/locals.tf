locals {
  # Region and Zone calculations
  region = join("-", slice(split("-", var.zone), 0, 2))
}
