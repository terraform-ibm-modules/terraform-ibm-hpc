variable "turn_on" {
  type        = string
  description = "It is used to turn on the null resources based on conditions."
}

variable "create_scale_cluster" {
  type        = string
  description = "It enables scale cluster configuration."
}

variable "clone_path" {
  type        = string
  description = "Scale repo clone path"
}
