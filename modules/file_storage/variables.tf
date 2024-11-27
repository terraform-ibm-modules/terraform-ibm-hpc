variable "zone" {
  description = "Region where VPC will be created. To find your VPC region, use `ibmcloud is regions` command to find available regions."
  type        = string
}

variable "resource_group_id" {
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
