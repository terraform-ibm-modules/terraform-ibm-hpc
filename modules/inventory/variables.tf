variable "hosts" {
  description = "Hosts"
  type        = list(string)
  default     = ["localhost"]
}

variable "inventory_path" {
  description = "Inventory file path"
  type        = string
  default     = "inventory.ini"
}

# tflint-ignore: all
variable "name_mount_path_map" {
  description = "File share mount path"
  #type        = list(string)
  default = null
}

variable "cloud_logs_ingress_private_endpoint" {
  description = "Cloud logs ingress private endpoint"
  type        = string
  default     = ""
}

variable "logs_enable_for_management" {
  description = "Set false to disable IBM Cloud Logs integration. If enabled, infrastructure and LSF application logs from Management Nodes will be ingested."
  type        = bool
  default     = false
}

variable "logs_enable_for_compute" {
  description = "Set false to disable IBM Cloud Logs integration. If enabled, infrastructure and LSF application logs from Compute Nodes will be ingested."
  type        = bool
  default     = false
}

variable "monitoring_enable_for_management" {
  description = "Set false to disable IBM Cloud Monitoring integration. If enabled, infrastructure and LSF application metrics from Management Nodes will be ingested."
  type        = bool
  default     = false
}

variable "monitoring_enable_for_compute" {
  description = "Set false to disable IBM Cloud Monitoring integration. If enabled, infrastructure and LSF application metrics from Management Nodes will be ingested."
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

variable "cloud_monitoring_prws_key" {
  description = "IBM Cloud Monitoring Prometheus Remote Write ingestion key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloud_monitoring_prws_url" {
  description = "IBM Cloud Monitoring Prometheus Remote Write ingestion url"
  type        = string
  default     = ""
}

# LDAP
variable "ldap_inventory_path" {
  description = "Inventory file path"
  type        = string
  default     = "ldap.ini"
}

variable "enable_ldap" {
  type        = bool
  default     = false
  description = "Set this option to true to enable LDAP for IBM Spectrum LSF, with the default value set to false."
}

variable "ldap_server" {
  type        = string
  default     = "null"
  description = "Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created."
}

variable "ldap_basedns" {
  type        = string
  default     = "lsf.com"
  description = "The dns domain name is used for configuring the LDAP server. If an LDAP server is already in existence, ensure to provide the associated DNS domain name."
}

variable "ldap_admin_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "The LDAP administrative password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@_+:) are required. It is important to avoid including the username in the password for enhanced security.[This value is ignored for an existing LDAP server]."
}

variable "ldap_server_cert" {
  type        = string
  sensitive   = true
  default     = "null"
  description = "Provide the existing LDAP server certificate. This value is required if the 'ldap_server' variable is not set to null. If the certificate is not provided or is invalid, the LDAP configuration may fail. For more information on how to create or obtain the certificate, please refer [existing LDAP server certificate](https://cloud.ibm.com/docs/allowlist/hpc-service?topic=hpc-service-integrating-openldap)."
}