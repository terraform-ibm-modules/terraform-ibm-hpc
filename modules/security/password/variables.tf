variable "length" {
  description = "The length of the password desired."
  type        = number
  default     = 12
}

variable "numeric" {
  description = "Use numbers in the password"
  type        = bool
  default     = true
}

variable "special" {
  description = "Use special characters in the password"
  type        = bool
  default     = true
}

# variable "lower" {
#   description = "Include lowercase alphabet characters in the result."
#   type        = bool
#   default     = true
# }

variable "upper" {
  description = "Include uppercase alphabet characters in the result."
  type        = bool
  default     = true
}

variable "min_lower" {
  description = "Minimum number of lowercase alphabet characters in the result."
  type        = number
  default     = 0
}

variable "min_upper" {
  description = "Minimum number of uppercase alphabet characters in the result."
  type        = number
  default     = 0
}

variable "override_special" {
  description = "Supply your own list of special characters to use for string generation."
  type        = string
  default     = "!@#$%&*()-_=+[]{}<>:?"
}

variable "min_numeric" {
  description = "Minimum number of numeric characters in the result."
  type        = number
  default     = 0
}
