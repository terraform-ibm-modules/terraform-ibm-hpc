variable "zone" {
  description = "Region where VPC will be created. To find your VPC region, use `ibmcloud is regions` command to find available regions."
  type        = string
}

##############################################################################
# Resource Groups Variables
##############################################################################

variable "resource_group" {
  description = "String describing resource groups to create or reference"
  type        = string
  default     = null
}

variable "file_shares" {
  type = list(
    object({
      name = string,
      size = number,
      iops = number
    })
  )
  default     = null
  description = "File shares details"
}

variable "encryption_key_crn" {
  type        = string
  description = "Encryption key CRN for file share encryption"
  default     = null
}

variable "vpc_id" {
  type        = string
  default     = null
  description = "VPC ID to mount file share"
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of Security group IDs to allow File share access"
  default     = null
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID to mount file share"
  default     = null
}

variable "prefix" {
  description = "A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
  type        = string
}

variable "existing_kms_instance_guid" {
  type        = string
  default     = null
  description = "GUID of boot volume encryption key"
}

variable "skip_iam_share_authorization_policy" {
  type        = bool
  default     = false
  description = "Set it to false if authorization policy is required for VPC file share to access kms. This can be set to true if authorization policy already exists. For more information on how to create authorization policy manually, see [creating authorization policies for VPC file share](https://cloud.ibm.com/docs/vpc?topic=vpc-file-s2s-auth&interface=ui)."
}

variable "kms_encryption_enabled" {
  description = "Enable Key management"
  type        = bool
  default     = true
}
