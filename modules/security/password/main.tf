resource "random_password" "generate" {
  length            = var.length
  special           = var.special
  numeric           = var.numeric
  upper             = var.upper
  min_lower         = var.min_lower
  min_upper         = var.min_upper
  override_special  = var.override_special
  min_numeric       = var.min_numeric
}