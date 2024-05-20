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

variable "payload_files" {
  description = "List of files that are to be transferred."
  type        = list(string)
  default     = []
}

variable "payload_dirs" {
  description = "List of directories that are to be transferred."
  type        = list(string)
  default     = []
}

variable "new_file_name" {
  description = "File name to be created."
  type        = string
  default     = ""
}

variable "new_file_content" {
  description = "Content of file to be created."
  type        = string
  default     = ""
}

variable "script_to_run" {
  description = "Name of script to be run."
  type        = string
}

variable "sudo_user" {
  description = "User we want to sudo to (e.g. 'root')."
  type        = string
  default     = ""
}

variable "with_bash" {
  description = "If we want a 'bash -c' execution of the script."
  type        = bool
  default     = false
}

variable "trigger_string" {
  description = "Changing this string will trigger a re-run"
  type        = string
  default     = ""
}
