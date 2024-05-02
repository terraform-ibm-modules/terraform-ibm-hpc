#subnet_cidr is the cidr range of input subnet.
variable "subnet_cidr" {
  description = "CIDR range of input subnet."
  type        = string
}

#vpc_address_prefix is the cidr range of vpc address prefixes.
variable "vpc_address_prefix" {
  description = "CIDR range of VPC address prefixes."
  type        = list(string)
  default     = []
}
