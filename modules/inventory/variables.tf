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

variable "scheduler" {
  default     = null
  type        = string
  description = "Select one of the scheduler (LSF/Symphony/Slurm/null)"
}