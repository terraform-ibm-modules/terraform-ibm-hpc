variable "ibmcloud_api_key" {
  description = "IBM Cloud API key for the IBM Cloud account where the IBM Cloud HPC cluster needs to be deployed. For more information on how to create an API key, see [Managing user API keys](https://cloud.ibm.com/docs/account?topic=account-userapikey)."
  type        = string
  sensitive   = true
  default     = null
}

variable "reservation_id" {
  type        = string
  sensitive   = true
  description = "Ensure that you have received the reservation ID from IBM technical sales. Reservation ID is a unique identifier to distinguish different IBM Cloud HPC service agreements. It must start with a letter and can only contain letters, numbers, hyphens (-), or underscores (_)."
  default     = null
}

variable "region" {
  description = "The region where the Code Engine project must be instantiated"
  type        = string
}

variable "resource_group_id" {
  description = "String describing resource groups to create or reference"
  type        = string
  default     = null
}

variable "solution" {
  type        = string
  default     = "hpc"
  description = "This is required to define a specific solution for the creation of reservation id's"
}
