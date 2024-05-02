variable "region" {
  description = "The region with which IBM CLI login should happen."
  type        = string
}

variable "ibmcloud_api_key" {
  description = "IBM Cloud API key for the IBM Cloud account where the IBM Cloud HPC cluster needs to be deployed. For more information on how to create an API key, see [Managing user API keys](https://cloud.ibm.com/docs/account?topic=account-userapikey)."
  type        = string
  sensitive   = true
}

variable "command" {
  description = "This is the command to execute."
  type        = string
}

variable "trigger_resource_id" {
  description = "A map of arbitrary strings that, when changed, will force the null resource to be replaced, re-running any associated provisioners."
  type        = any
}
