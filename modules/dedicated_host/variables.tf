########################################################################################################################
# Dedicated Host Input Variables
########################################################################################################################

variable "prefix" {
  type        = string
  description = "Name of the resources"
}

variable "resource_tags" {
  type        = list(string)
  description = "A list of access tags to apply to the resources created by the module."
  default     = []
}

variable "resource_group_id" {
  type        = string
  description = "The name of the resource group where you want to create the service."
}

variable "existing_host_group" {
  type        = bool
  description = "Allows users to use an existing dedicated host group when set to true. Checks for the host_group_name and validates if exists, if not creates new one."
  default     = false
}

variable "zone" {
  type        = list(string)
  description = "Particular zone selection for creating the dedicated host."
  default     = null
}

variable "family" {
  description = "Family defines the purpose of the dedicated host, The dedicated host family can be defined from balanced,compute or memory. Refer [Understanding DH Profile family](https://cloud.ibm.com/docs/vpc?topic=vpc-dh-profiles&interface=ui) for more details"
  type        = string
}

variable "class" {
  description = "Profile class of the dedicated host, this has to be defined based on the VSI usage. Refer [Understanding DH Class](https://cloud.ibm.com/docs/vpc?topic=vpc-dh-profiles&interface=ui) for more details"
  type        = string
}

variable "profile" {
  description = "Profile for the dedicated hosts(size and resources). Refer [Understanding DH Profile](https://cloud.ibm.com/docs/vpc?topic=vpc-dh-profiles&interface=ui) for more details"
  type        = string
}
