variable "cluster_host" {
  description = "Cluster hosts to be used for ssh connectivity."
  type        = list(string)
}

variable "cluster_user" {
  description = "Cluster user to be used for ssh connectivity."
  type        = string
}

variable "cluster_private_key" {
  description = "Cluster private key to be used for ssh connectivity."
  type        = string
}

variable "login_host" {
  description = "Login host to be used for ssh connectivity."
  type        = string
}

variable "login_user" {
  description = "Login user to be used for ssh connectivity."
  type        = string
}

variable "login_private_key" {
  description = "Login private key to be used for ssh connectivity."
  type        = string
}

variable "command" {
  description = "These are the list of commands to execute."
  type        = list(string)
}
