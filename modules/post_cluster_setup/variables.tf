variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  default     = null
  description = "IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required."
}

variable "resource_group" {
  description = "String describing resource groups to create or reference"
  type        = string
  default     = null
}

variable "vpc_region" {
  type        = string
  default     = null
  description = "vpc region"
}

variable "turn_on" {
  type        = string
  description = "It is used to turn on the null resources based on conditions."
}

variable "storage_turn_on" {
  type        = string
  description = "To determine the storage cluster is enabled or not."
}

variable "compute_turn_on" {
  type        = string
  description = "To determine the compute cluster is enabled or not."
}

variable "create_scale_cluster" {
  type        = string
  description = "It enables scale cluster configuration."
}

variable "clone_path" {
  type        = string
  description = "Scale repo clone path"
}

variable "scale_encryption_servers" {
  type        = list(string)
  description = "GKLM encryption server IP's."
}

variable "scale_encryption_type" {
  type        = string
  description = "To enable filesystem encryption, specify either 'key_protect' or 'gklm'. If neither is specified, the default value will be 'null' and encryption is disabled"
}

variable "scale_encryption_admin_username" {
  type        = string
  description = "The default Admin username for Security Key Lifecycle Manager(GKLM)."
}

variable "scale_encryption_admin_password" {
  type        = string
  description = "Password that is used for performing administrative operations for the GKLM.The password must contain at least 8 characters and at most 20 characters. For a strong password, at least three alphabetic characters are required, with at least one uppercase and one lowercase letter.  Two numbers, and at least one special character from this(~@_+:). Make sure that the password doesn't include the username. Visit this [page](https://www.ibm.com/docs/en/gklm/3.0.1?topic=roles-password-policy) to know more about password policy of GKLM. "
}

variable "security_group_id" {
  type        = string
  description = "The ID of the security group."
}
