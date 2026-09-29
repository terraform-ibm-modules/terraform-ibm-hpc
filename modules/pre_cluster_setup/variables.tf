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

variable "storage_hosts" {
  description = "Map of storage hosts configuration"
  type        = map(string)
  default     = {}
}

variable "storage_mgmnt_hosts" {
  description = "Map of storage management hosts configuration"
  type        = map(string)
  default     = {}
}

variable "storage_tb_hosts" {
  description = "Map of storage TB (tape backup?) hosts configuration"
  type        = map(string)
  default     = {}
}

variable "compute_hosts" {
  description = "Map of compute hosts configuration"
  type        = map(string)
  default     = {}
}

variable "compute_mgmnt_hosts" {
  description = "Map of compute management hosts configuration"
  type        = map(string)
  default     = {}
}

variable "client_hosts" {
  description = "Map of client hosts configuration"
  type        = map(string)
  default     = {}
}

variable "protocol_hosts" {
  description = "Map of protocol hosts configuration"
  type        = map(string)
  default     = {}
}

variable "gklm_hosts" {
  description = "Map of GKLM (Global Key Lifecycle Manager?) hosts configuration"
  type        = map(string)
  default     = {}
}

variable "afm_hosts" {
  description = "Map of AFM (Azure File Manager?) hosts configuration"
  type        = map(string)
  default     = {}
}

variable "storage_bms_hosts" {
  description = "Map of storage BMS (Bare Metal Server?) hosts configuration"
  type = map(object({
    name = string
    id   = optional(string)
  }))
  default = {}
}

variable "storage_tb_bms_hosts" {
  description = "Map of storage TB BMS (tape backup bare metal servers?) configuration"
  type = map(object({
    name = string
    id   = optional(string)
  }))
  default = {}
}

variable "protocol_bms_hosts" {
  description = "Map of protocol BMS (bare metal servers) configuration"
  type = map(object({
    name = string
    id   = optional(string)
  }))
  default = {}
}

variable "afm_bms_hosts" {
  description = "Map of AFM BMS (bare metal servers) configuration"
  type = map(object({
    name = string
    id   = optional(string)
  }))
  default = {}
}

variable "ppnlb_hosts" {
  description = "Map of PPNLB hosts configuration"
  type        = map(string)
  default     = {}
}

variable "clone_path" {
  type        = string
  description = "Scale repo clone path"
}

variable "scheduler" {
  default     = null
  type        = string
  description = "Select one of the scheduler (Scale/LSF/Symphony/Slurm/null)"
}

variable "storage_type" {
  type        = string
  default     = "vsi"
  description = "Select the required storage type(vsi/baremetal/eval)."
}

variable "domain_names" {
  type = object({
    compute  = string
    storage  = optional(string)
    protocol = optional(string)
    client   = optional(string)
    gklm     = optional(string)
    ppnlb    = optional(string)
  })
  default = {
    compute  = "comp.com"
    storage  = "strg.com"
    protocol = "ces.com"
    client   = "clnt.com"
    gklm     = "gklm.com"
    ppnlb    = "strgscale.private"
  }
  description = "IBM Cloud HPC DNS domain names."
}

variable "storage_interface" {
  description = "Network interface to use for storage traffic"
  type        = string
}

variable "protocol_interface" {
  description = "Network interface to use for protocol traffic"
  type        = string
}

variable "enable_sec_interface_compute" {
  description = "Secondary Network interface to use for compute for enabling Parallel VNic feature"
  type        = bool
}

variable "enable_protocol" {
  description = "Enable protocol services (true/false)"
  type        = bool
}

variable "colocate_protocol_instances" {
  type        = bool
  default     = true
  description = "Enable it to use storage instances as protocol instances"
}

variable "protocol_subnets" {
  description = "List of subnets available for protocol services"
  type        = string
}

variable "bms_boot_drive_encryption" {
  type        = bool
  default     = false
  description = "To enable the encryption for the boot drive of bare metal server. Select true or false"
}

variable "scale_encryption_type" {
  type        = string
  default     = null
  description = "To enable filesystem encryption, specify either 'key_protect' or 'gklm'. If neither is specified, the default value will be 'null' and encryption is disabled"
}

variable "enable_private_path_nlb" {
  type        = bool
  default     = false
  description = "Enable private path network load balancer for providing CES (NFS) storage."
}

variable "protocol_instance_eth1_mtu" {
  type        = number
  description = "MTU for protocol instance eth1. When private path NLB is enabled, MTU must be 8500 or lower. When disabled, MTU can be up to 9000."
  default     = 9000
}

variable "observability_monitoring_enable" {
  description = "Enables or disables IBM Cloud Monitoring integration. When enabled, the Grafana bridge is deployed on management nodes to expose IBM Storage Scale metrics, and the unified agent collects infrastructure and filesystem data across the cluster. This must be set to true if monitoring is required for the storage cluster."
  type        = bool
  default     = false
}

variable "cloud_monitoring_access_key" {
  description = "IBM Cloud Monitoring access key for agents to use"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloud_monitoring_ingestion_url" {
  description = "IBM Cloud Monitoring ingestion url for agents to use"
  type        = string
  default     = ""
}

variable "enable_sccwp" {
  description = "Flag to enable or disable SCC Workload Protection agent configuration"
  type        = bool
  default     = false
}

variable "sccwp_api_endpoint" {
  description = "SCC Workload Protection API endpoint for the Sysdig agent (must be formatted without https:// and /api)"
  type        = string
  default     = ""
}

variable "sccwp_access_key" {
  description = "SCC Workload Protection access key for standalone agent authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "sccwp_ingestion_endpoint" {
  description = "SCC Workload Protection ingestion collector URL"
  type        = string
  default     = ""
}

variable "login_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the bastion node. If set to null, the solution will automatically create the necessary security group and rules."
}

variable "storage_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the storage nodes. If set to null, the solution will automatically create the necessary security group and rules."
}

variable "compute_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the compute nodes. If set to null, the solution will automatically create the necessary security group and rules."
}

variable "client_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the client nodes. If set to null, the solution will automatically create the necessary security group and rules."
}

variable "gklm_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the gklm nodes. If set to null, the solution will automatically create the necessary security group and rules."
}

variable "ldap_security_group_name" {
  type        = string
  default     = null
  description = "Provide the security group name to provision the ldap nodes. If set to null, the solution will automatically create the necessary security group and rules."
}
