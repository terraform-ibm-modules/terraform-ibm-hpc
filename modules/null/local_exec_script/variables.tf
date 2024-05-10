variable "script_path" {
  description = "The path to the script to execute"
}

variable "script_arguments" {
  description = "The arguments to pass to the script"
}

variable "script_environment" {
  description = "The environment variables to pass to the script"
  type        = map(string)
}
