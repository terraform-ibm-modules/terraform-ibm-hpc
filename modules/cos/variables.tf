variable "prefix" {
  type        = string
  description = "A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters."
}

variable "resource_group_id" {
  type        = string
  description = "Resource group id."
}

variable "cos_instance_plan" {
  type        = string
  description = "COS instance plan."
}
variable "cos_instance_location" {
  type        = string
  description = "COS instance location."
}

variable "cos_instance_service" {
  type        = string
  description = "COS instance service."
}

variable "cos_hmac_role" {
  type        = string
  description = "HMAC key role."
}

variable "new_instance_bucket_hmac" {
  type = list(
    object({
      afm_fileset          = string,
      mode                 = string,
      cos_instance         = string,
      bucket_name          = string,
      bucket_region        = string,
      cos_service_cred_key = string,
      bucket_type          = string,
      bucket_storage_class = string
    })
  )
  description = "It creates new COS instance, Bucket and Hmac Key"
}
variable "exstng_instance_new_bucket_hmac" {
  type = list(
    object({
      afm_fileset          = string,
      mode                 = string,
      cos_instance         = string,
      bucket_name          = string,
      bucket_region        = string,
      cos_service_cred_key = string,
      bucket_type          = string,
      bucket_storage_class = string
    })
  )
  description = "It creates new COS instance, Bucket and Hmac Key"
}
variable "exstng_instance_bucket_new_hmac" {
  type = list(
    object({
      afm_fileset          = string,
      mode                 = string,
      cos_instance         = string,
      bucket_name          = string,
      bucket_region        = string,
      cos_service_cred_key = string,
      bucket_type          = string,
      bucket_storage_class = string
    })
  )
  description = "It creates new COS instance, Bucket and Hmac Key"
}
variable "exstng_instance_hmac_new_bucket" {
  type = list(
    object({
      afm_fileset          = string,
      mode                 = string,
      cos_instance         = string,
      bucket_name          = string,
      bucket_region        = string,
      cos_service_cred_key = string,
      bucket_type          = string,
      bucket_storage_class = string
    })
  )
  description = "It creates new COS instance, Bucket and Hmac Key"
}
variable "exstng_instance_bucket_hmac" {
  type = list(
    object({
      afm_fileset          = string,
      mode                 = string,
      cos_instance         = string,
      bucket_name          = string,
      bucket_region        = string,
      cos_service_cred_key = string,
      bucket_type          = string,
      bucket_storage_class = string
    })
  )
  description = "It creates new COS instance, Bucket and Hmac Key"
}

variable "filesystem" {
  type        = string
  description = "Storage filesystem name."
}