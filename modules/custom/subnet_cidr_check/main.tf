
locals {
  subnet_cidr = [for i in [var.subnet_cidr] : [(((split(".", cidrhost(i, 0))[0]) * pow(256, 3)) #192
    + ((split(".", cidrhost(i, 0))[1]) * pow(256, 2))
    + ((split(".", cidrhost(i, 0))[2]) * pow(256, 1))
    + ((split(".", cidrhost(i, 0))[3]) * pow(256, 0))), (((split(".", cidrhost(i, -1))[0]) * pow(256, 3)) #192
    + ((split(".", cidrhost(i, -1))[1]) * pow(256, 2))
    + ((split(".", cidrhost(i, -1))[2]) * pow(256, 1))
  + ((split(".", cidrhost(i, -1))[3]) * pow(256, 0)))]]
  vpc_address_prefix = [for i in var.vpc_address_prefix : [(((split(".", cidrhost(i, 0))[0]) * pow(256, 3)) #192
    + ((split(".", cidrhost(i, 0))[1]) * pow(256, 2))
    + ((split(".", cidrhost(i, 0))[2]) * pow(256, 1))
    + ((split(".", cidrhost(i, 0))[3]) * pow(256, 0))), (((split(".", cidrhost(i, -1))[0]) * pow(256, 3))
    + ((split(".", cidrhost(i, -1))[1]) * pow(256, 2))
    + ((split(".", cidrhost(i, -1))[2]) * pow(256, 1))
  + ((split(".", cidrhost(i, -1))[3]) * pow(256, 0)))]]
}
