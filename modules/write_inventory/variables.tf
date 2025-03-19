variable "json_inventory_path" {
  type        = string
  default     = "inventory.json"
  description = "Json inventory file path"
}

variable "lsf_masters" {
  type        = list(string)
  default     = null
  description = "list of lsf master nodes"
}

variable "lsf_servers" {
  type        = list(string)
  default     = null
  description = "list of lsf server nodes"
}

variable "lsf_clients" {
  type        = list(string)
  default     = null
  description = "list of lsf client nodes"
}

variable "gui_hosts" {
  type        = list(string)
  default     = null
  description = "list of lsf gui nodes"
}

variable "db_hosts" {
  type        = list(string)
  default     = null
  description = "list of lsf gui db nodes"
}

variable "my_cluster_name" {
  type        = string
  default     = null
  description = "Name of lsf cluster"
}

variable "ha_shared_dir" {
  type        = string
  default     = null
  description = "Path for lsf shared dir"
}

variable "nfs_install_dir" {
  type        = string
  default     = null
  description = "Private key file path"
}

variable "Enable_Monitoring" {
  type        = bool
  default     = null
  description = "Option to enable the monitoring"
}

variable "lsf_deployer_hostname" {
  type        = string
  default     = null
  description = "Deployer host name"
}

variable "enable_hyperthreading" {
  description = "Enable or disable hyperthreading"
  type        = bool
  default     = null
}

variable "vcpus" {
  description = "Number of vCPUs"
  type        = number
  default     = null
}

variable "ncores" {
  description = "Number of cores"
  type        = number
  default     = null
}

variable "ncpus" {
  description = "Number of CPUs"
  type        = number
  default     = null
}

variable "memInMB" {
  description = "Memory in MB"
  type        = number
  default     = null
}

variable "rc_maxNum" {
  description = "Maximum number of resource instances"
  type        = number
  default     = null
}

variable "rc_profile" {
  description = "Resource profile"
  type        = string
  default     = null
}

variable "imageID" {
  description = "Image ID for the compute instance"
  type        = string
  default     = null
}

variable "compute_subnet_id" {
  description = "Compute subnet ID"
  type        = string
  default     = null
}

variable "region" {
  description = "Deployment region"
  type        = string
  default     = null
}

variable "resource_group_id" {
  description = "Resource group ID"
  type        = string
  default     = null
}

variable "compute_subnets_cidr" {
  description = "List of compute subnets CIDR"
  type        = list(string)
  default     = null
}

variable "dynamic_compute_instances" {
  description = "Dynamic compute instances configuration"
  type        = list(map(any))
  default     = null
}

variable "compute_ssh_keys_ids" {
  description = "List of compute SSH key IDs"
  type        = list(string)
  default     = null
}

variable "ibmcloud_api_key" {
  type        = string
  sensitive   = true
  default     = null
}

variable "zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = null
}

variable "dns_domain_names" {
  type = object({
    compute  = string
    storage  = string
    protocol = string
  })
  default = {
    compute  = "comp.com"
    storage  = "strg.com"
    protocol = "ces.com"
  }
  description = "IBM Cloud HPC DNS domain names."
}

variable "compute_security_group_id" {
  type        = list(string)
  description = "List of Security group IDs to allow File share access"
  default     = null
}

variable "vpc_id" {
  type        = string
  default     = null
  description = "ID of an existing VPC in which the cluster resources will be deployed."
}

variable "compute_subnet_crn" {
  type        = string
  default     = null
  description = "ID of an existing VPC in which the cluster resources will be deployed."
}

variable "compute_public_key_content" {
  type        = string
  sensitive   = true
  default     = null
  description = "Compute security key content."
}

variable "compute_private_key_content" {
  type        = string
  sensitive   = true
  default     = null
  description = "Compute security key content."
}

##############################################################################
# LDAP Variables
##############################################################################

variable "enable_ldap" {
  type        = bool
  default     = false
  description = "Set this option to true to enable LDAP for IBM Spectrum LSF, with the default value set to false."
}

variable "ldap_basedns" {
  type        = string
  default     = "lsf.com"
  description = "The dns domain name is used for configuring the LDAP server. If an LDAP server is already in existence, ensure to provide the associated DNS domain name."
}

variable "ldap_server" {
  type        = string
  default     = "null"
  description = "Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created."
}

variable "ldap_server_cert" {
  type        = string
  sensitive   = true
  default     = "null"
  description = "Provide the existing LDAP server certificate. This value is required if the 'ldap_server' variable is not set to null. If the certificate is not provided or is invalid, the LDAP configuration may fail. For more information on how to create or obtain the certificate, please refer [existing LDAP server certificate](https://cloud.ibm.com/docs/allowlist/hpc-service?topic=hpc-service-integrating-openldap)."
}

variable "ldap_admin_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "The LDAP administrative password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@_+:) are required. It is important to avoid including the username in the password for enhanced security.[This value is ignored for an existing LDAP server]."
}

variable "ldap_user_name" {
  type        = string
  default     = ""
  description = "Custom LDAP User for performing cluster operations. Note: Username should be between 4 to 32 characters, (any combination of lowercase and uppercase letters).[This value is ignored for an existing LDAP server]"
}

variable "ldap_user_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "The LDAP user password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@_+:) are required.It is important to avoid including the username in the password for enhanced security.[This value is ignored for an existing LDAP server]."
}

variable "ldap_vsi_profile" {
  type        = string
  default     = "cx2-2x4"
  description = "Specify the virtual server instance profile type to be used to create the ldap node for the IBM Spectrum LSF cluster. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
}

variable "ldap_vsi_osimage_name" {
  type        = string
  default     = "ibm-ubuntu-22-04-4-minimal-amd64-3"
  description = "Image name to be used for provisioning the LDAP instances. By default ldap server are created on Ubuntu based OS flavour."
}

variable "ldap_server_ip" {
  type        = string
  default     = null
  description = "List of LDAP primary IPs."
}