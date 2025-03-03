##############################################################################
# Account Variables
##############################################################################

variable "ibmcloud_api_key" {
  description = "IBM Cloud API key for the IBM Cloud account where the IBM Spectrum LSF cluster needs to be deployed. For more information on how to create an API key, see [Managing user API keys](https://cloud.ibm.com/docs/account?topic=account-userapikey)."
  type        = string
  sensitive   = true
  validation {
    condition     = var.ibmcloud_api_key != ""
    error_message = "The API key for IBM Cloud must be set."
  }
}

##############################################################################
# Resource Groups Variables
##############################################################################

variable "existing_resource_group" {
  description = "Specify the name of the existing resource group in your IBM Cloud account where VPC resources will be deployed. By default, the resource group is set to 'Default.' In some older accounts, it may be 'default,' so please verify the resource group name before proceeding. If the value is set to \"null\", the automation will create two separate resource groups: 'workload-rg' and 'service-rg.' For more details, see Managing resource groups."
  type        = string
  default     = "Default"
  validation {
    condition     = var.existing_resource_group != null
    error_message = "If you want to provide null for resource_group variable, it should be within double quotes."
  }
}

##############################################################################
# Module Level Variables
##############################################################################

variable "cluster_prefix" {
  description = "The prefix is used to name the IBM Cloud LSF cluster and the resources provisioned to build the  cluster instance. Each Spectrum LSF cluster must have a unique name, so ensure the prefix is distinct. It must begin with a lowercase letter and can only include lowercase letters, digits, and hyphens. Hyphens must be followed by a lowercase letter or digit, with no leading, trailing, or consecutive hyphens. The prefix length must be less than 16 characters."
  type        = string
  default     = "hpc-lsf"

  validation {
    error_message = "Prefix must start with a lowercase letter and contain only lowercase letters, digits, and hyphens in between. Hyphens must be followed by at least one lowercase letter or digit. There are no leading, trailing, or consecutive hyphens."
    condition     = can(regex("^[a-z](?:[a-z0-9]*(-[a-z0-9]+)*)?$", var.cluster_prefix))
  }
  validation {
    condition     = length(var.cluster_prefix) <= 16
    error_message = "The cluster_prefix must be 16 characters or fewer."
  }
}

variable "solution" {
  type        = string
  default     = "lsf"
  description = "Provide the value for the solution that is needed for the support of lsf and HPC"
  validation {
    condition     = contains(["hpc", "lsf"], var.solution)
    error_message = "supported values are only lsf for BYOL and HPC"
  }
}

variable "zones" {
  description = "Specify the IBM Cloud zone within the chosen region where the IBM Spectrum LSF cluster will be deployed. A single zone input is required, and the management nodes, file storage shares, and compute nodes will all be provisioned in this zone.[Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region#get-zones-using-the-cli)."
  type        = list(string)
  default     = ["us-east-1"]
  validation {
    condition     = length(var.zones) == 1
    error_message = "HPC product deployment supports only a single zone. Provide a value for a single zone from the supported regions: eu-de-2 or eu-de-3 for eu-de, us-east-1 or us-east-3 for us-east, and us-south-1 for us-south."
  }
}

variable "cluster_name" {
  type        = string
  description = "Provide a unique cluster name that LSF uses to configure and group the cluster. Without this name, LSF cannot form a cluster, and the initial deployments will fail. The cluster name can be up to 39 alphanumeric characters and may include underscores (_), hyphens (-), and periods (.). Spaces and other special characters are not allowed. Avoid using the name of any host or user as the cluster name. Note that the cluster name cannot be changed after deployment."
  validation {
    condition     = 0 < length(var.cluster_name) && length(var.cluster_name) < 40 && can(regex("^[a-zA-Z0-9_.-]+$", var.cluster_name))
    error_message = "The Cluster name can be up to 39 alphanumeric characters including the underscore (_), the hyphen (-), and the period (.) characters. Other special characters and spaces are not allowed."
  }
}

variable "reservation_id" {
  type        = string
  sensitive   = true
  default     = null
  description = "Ensure that you have received the reservation ID from IBM technical sales. Reservation ID is a unique identifier to distinguish different IBM Cloud HPC service agreements. It must start with a letter and can only contain letters, numbers, hyphens (-), or underscores (_)."
}

variable "ibm_customer_number" {
  type        = string
  sensitive   = true
  default     = null
  description = "Comma-separated list of the IBM Customer Number(s) (ICN) that is used for the Bring Your Own License (BYOL) entitlement check. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn)."
}

##############################################################################
# VPC Variables
##############################################################################

variable "vpc_name" {
  type        = string
  description = "Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
  default     = null
}

variable "cluster_subnet_ids" {
  type        = list(string)
  default     = []
  description = "Provide the list of existing subnet ID under the existing VPC where the cluster will be provisioned. One subnet ID is required as input value. The management nodes, file storage shares, and compute nodes will be deployed in the same zone."
  validation {
    condition     = contains([0, 1], length(var.cluster_subnet_ids))
    error_message = "The subnet_id value should either be empty or contain exactly one element. Provide only a single subnet value from the supported zones."
  }
}

variable "login_subnet_id" {
  type        = string
  default     = null
  description = "Provide the list of existing subnet ID under the existing VPC, where the login/bastion server will be provisioned. One subnet id is required as input value for the creation of login node and bastion in the same zone as the management nodes. Note: Provide a different subnet id for login_subnet_id, do not overlap or provide the same subnet id that was already provided for cluster_subnet_ids."
}

variable "vpc_cidr" {
  description = "Creates the address prefix for the new VPC, when the vpc_name variable is empty. The VPC requires an address prefix for creation of subnet in a single zone. The subnet are created with the specified CIDR blocks. For more information, see [Setting IP ranges](https://cloud.ibm.com/docs/vpc?topic=vpc-vpc-addressing-plan-design)."
  type        = string
  default     = "10.241.0.0/18"
}

variable "vpc_cluster_private_subnets_cidr_blocks" {
  type        = list(string)
  default     = ["10.241.0.0/20"]
  description = "Provide the CIDR block required for the creation of the compute cluster's private subnet. One CIDR block is required. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Ensure the selected CIDR block size can accommodate the maximum number of management and dynamic compute nodes expected in your cluster. For more information on CIDR block size selection, refer to the documentation, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc)."
  validation {
    condition     = length(var.vpc_cluster_private_subnets_cidr_blocks) == 1
    error_message = "Single zone is supported to deploy resources. Provide a CIDR range of subnets creation."
  }
}

variable "vpc_cluster_login_private_subnets_cidr_blocks" {
  type        = list(string)
  default     = ["10.241.16.0/28"]
  description = "Provide the CIDR block required for the creation of the login cluster's private subnet. Only one CIDR block is needed. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Since the login subnet is used only for the creation of login virtual server instances, provide a CIDR range of /28."
  validation {
    condition     = length(var.vpc_cluster_login_private_subnets_cidr_blocks) <= 1
    error_message = "Only a single zone is supported to deploy resources. Provide a CIDR range of subnet creation."
  }
  validation {
    condition     = tonumber(regex("/(\\d+)", join(",", var.vpc_cluster_login_private_subnets_cidr_blocks))[0]) <= 28
    error_message = "This subnet is used to create only a login virtual server instance. Providing a larger CIDR size will waste the usage of available IPs. A CIDR range of /28 is sufficient for the creation of the login subnet."
  }
}

##############################################################################
# Access Variables
##############################################################################

variable "remote_allowed_ips" {
  type        = list(string)
  description = "Comma-separated list of IP addresses that can access the IBM Spectrum LSF cluster instance through an SSH interface. For security purposes, provide the public IP addresses assigned to the devices that are authorized to establish SSH connections (for example, [\"169.45.117.34\"]). To fetch the IP address of the device, use [https://ipv4.icanhazip.com/](https://ipv4.icanhazip.com/)."
  validation {
    condition = alltrue([
      for o in var.remote_allowed_ips : !contains(["0.0.0.0/0", "0.0.0.0"], o)
    ])
    error_message = "For security, provide the public IP addresses assigned to the devices authorized to establish SSH connections. Use https://ipv4.icanhazip.com/ to fetch the ip address of the device."
  }
  validation {
    condition = alltrue([
      for a in var.remote_allowed_ips : can(regex("^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/(3[0-2]|2[0-9]|1[0-9]|[0-9]))?$", a))
    ])
    error_message = "The provided IP address format is not valid. Check if the IP address contains a comma instead of a dot, and ensure there are double quotation marks between each IP address range if using multiple IP ranges. For multiple IP address, use the format [\"169.45.117.34\",\"128.122.144.145\"]."
  }
}

##############################################################################
# Compute Variables
##############################################################################

variable "bastion_ssh_keys" {
  type        = list(string)
  description = "Provide the list of SSH key names configured in your IBM Cloud account to establish a connection to the Spectrum LSF bastion and login node. Make sure the SSH key exists in the same resource group and region where the cluster is being provisioned. To pass multiple SSH keys, use the format [\"key-name-1\", \"key-name-2\"]. If you don't have an SSH key in your IBM Cloud account, you can create one by following the provided .[SSH Keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
}

variable "compute_ssh_keys" {
  type        = list(string)
  description = "Provide the list of SSH key names configured in your IBM Cloud account to establish a connection to the Spectrum LSF cluster node. Ensure the SSH key is present in the same resource group and region where the cluster is being provisioned. To pass multiple SSH keys, use the format [\"key-name-1\", \"key-name-2\"]. If you do not have an SSH key in your IBM Cloud account, create one by following the provided instructions.[SSH Keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys).."
}

variable "login_node_instance_type" {
  type        = string
  default     = "bx2-2x8"
  description = "Specify the virtual server instance profile type to be used to create the login node for the IBM Spectrum LSF cluster. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  validation {
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.login_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "management_image_name" {
  type        = string
  default     = "hpc-lsf10-rhel810-v1"
  description = "Name of the custom image that you want to use to create virtual server instances in your IBM Cloud account to deploy the IBM Cloud Spectrum LSF cluster management nodes. By default, the solution uses a RHEL810 base image with additional software packages mentioned [here](https://cloud.ibm.com/docs/ibm-spectrum-lsf#create-custom-image). If you would like to include your application-specific binary files, follow the instructions in [ Planning for custom images ](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the lsf cluster through this offering."
}

variable "compute_image_name" {
  type        = string
  default     = "hpcaas-lsf10-rhel810-compute-v8"
  description = "Name of the custom image that you want to use to create virtual server instances in your IBM Cloud account to deploy the IBM Cloud Spectrum LSF cluster compute (static/dynamic) nodes. By default, the solution uses a RHEL 8-10 base OS image with additional software packages mentioned [here](https://cloud.ibm.com/docs/ibm-spectrum-lsf#create-custom-image). If you would like to include your application-specific binary files, follow the instructions in [ Planning for custom images ](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the lsf cluster through this offering."
}

variable "login_image_name" {
  type        = string
  default     = "hpcaas-lsf10-rhel810-compute-v8"
  description = "Name of the custom image that you want to use to create virtual server instances in your IBM Cloud account to deploy the IBM Cloud Spectrum LSF cluster login node. By default, the solution uses a RHEL 8-10 OS image with additional software packages mentioned [here](https://cloud.ibm.com/docs/ibm-spectrum-lsf#create-custom-image). If you would like to include your application-specific binary files, follow the instructions in [ Planning for custom images ](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the lsf cluster through this offering."
}

variable "management_node_instance_type" {
  type        = string
  default     = "bx2-16x64"
  description = "Specify the virtual server instance profile type to be used to create the management nodes for the IBM Cloud LSF cluster. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  validation {
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.management_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "management_node_count" {
  type        = number
  default     = 2
  description = "Specify the total number of management nodes, with a value between 1 and 10."
  validation {
    condition     = 1 <= var.management_node_count && var.management_node_count <= 10
    error_message = "Input \"management_node_count\" must be must be greater than or equal to 1 and less than or equal to 10."
  }
}

variable "worker_node_instance_type" {
  type = list(object({
    count         = number
    instance_type = string
  }))
  description = "The minimum number of worker nodes represents the static nodes provisioned during cluster creation. The solution supports different instance types, so specify the node count based on the requirements for each instance profile. For dynamic node provisioning, the automation will select the first profile from the list. Ensure sufficient account-level capacity if specifying a higher instance profile.. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  default = [
    {
      count         = 0
      instance_type = "bx2-4x16"
    },
    {
      count         = 0
      instance_type = "cx2-8x16"
    }
  ]
}

variable "worker_node_max_count" {
  type        = number
  default     = 10
  description = "The maximum number of worker nodes that can be deployed in the Spectrum LSF cluster. In order to use the [Resource Connector](https://www.ibm.com/docs/en/spectrum-lsf/10.1.0?topic=lsf-resource-connnector) feature to dynamically create and delete worker nodes based on workload demand, the value selected for this parameter must be larger than the total count of worker_node_instance_type. If you plan to deploy only static worker nodes in the LSF cluster."
  validation {
    condition     = 1 <= var.worker_node_max_count && var.worker_node_max_count <= 500
    error_message = "Input \"worker_node_max_count must\" be >= 1 and <= 500."
  }
}

variable "custom_file_shares" {
  type = list(object({
    mount_path = string,
    size       = optional(number),
    iops       = optional(number),
    nfs_share  = optional(string)
  }))
  default     = [{ mount_path = "/mnt/vpcstorage/tools", size = 100, iops = 2000 }, { mount_path = "/mnt/vpcstorage/data", size = 100, iops = 6000 }, { mount_path = "/mnt/scale/tools", nfs_share = "" }]
  description = "Provide details for customizing your shared file storage layout, including mount points, sizes (in GB), and IOPS ranges for up to five file shares if using VPC file storage as the storage option.If using IBM Storage Scale as an NFS mount, update the appropriate mount path and nfs_share values created from the Storage Scale cluster. Note that VPC file storage supports attachment to a maximum of 256 nodes. Exceeding this limit may result in mount point failures due to attachment restrictions.For more information, see [Storage options](https://test.cloud.ibm.com/docs/hpc-ibm-spectrumlsf?topic=hpc-ibm-spectrumlsf-integrating-scale#integrate-scale-and-hpc)."
  validation {
    condition     = length([for item in var.custom_file_shares : item if item.nfs_share == null]) <= 5
    error_message = "The VPC storage custom file share count \"custom_file_shares\" must be less than or equal to 5. Unlimited NFS mounts are allowed."
  }
  validation {
    condition     = length([for mounts in var.custom_file_shares : mounts.mount_path]) == length(toset([for mounts in var.custom_file_shares : mounts.mount_path]))
    error_message = "Mount path values should not be duplicated."
  }
  validation {
    condition     = alltrue([for mounts in var.custom_file_shares : can(mounts.size) && mounts.size != null ? (10 <= mounts.size && mounts.size <= 32000) : true])
    error_message = "The custom_file_share size must be greater than or equal to 10 and less than or equal to 32000."
  }
}

variable "storage_security_group_id" {
  type        = string
  default     = null
  description = "Provide the storage security group ID from the Spectrum Scale storage cluster if the mount_path in the cluster_file_share variable is set to use Scale fileset mount points. This security group is essential for establishing connections between the Spectrum LSF cluster nodes and NFS mount points, ensuring the nodes can access the specified mount points."
}

##############################################################################
# DNS Template Variables
##############################################################################

variable "dns_instance_id" {
  type        = string
  default     = null
  description = "Provide the ID of an existing IBM Cloud DNS service instance to avoid creating a new one. Note: If dns_instance_id is not set to null, a new DNS zone will be created within the specified DNS service instance."
}

variable "dns_domain_name" {
  type = object({
    compute = string
  })
  default = {
    compute = "lsf.com"
  }
  description = "IBM Cloud DNS Services domain name to be used for the IBM Spectrum LSF cluster."
  validation {
    condition = can(regex("^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9])\\.com$", var.dns_domain_name.compute))
    error_message = "The domain name provided for compute is not a fully qualified domain name (FQDN). An FQDN can contain letters (a-z, A-Z), digits (0-9), hyphens (-), dots (.), and must start and end with an alphanumeric character."
  }
}

variable "dns_custom_resolver_id" {
  type        = string
  default     = null
  description = "Provide the id of existing IBM Cloud DNS custom resolver to skip creating a new custom resolver. If the value is set to null, a new dns custom resolver shall be created and associated to the vpc. Note: A VPC can be associated only to a single custom resolver, please provide the id of custom resolver if it is already associated to the VPC."
}

##############################################################################
# Observability Variables
##############################################################################

variable "enable_cos_integration" {
  type        = bool
  default     = false
  description = "Set to true to create an extra cos bucket to integrate with HPC cluster deployment."
}

variable "cos_instance_name" {
  type        = string
  default     = null
  description = "Provide the name of the existing COS instance where the logs for the enabled functionalities will be stored."
}

variable "observability_atracker_enable" {
  type        = bool
  default     = true
  description = "Configures Activity Tracker Event Routing to determine how audit events routed. While multiple Activity Tracker Event Routing can be created, only one is needed to capture all events. If an existing Activity Tracker is already integrated with a COS bucket or IBM Cloud Logs instance, set this value to false to avoid creating redundant trackers. All events can then be monitored and accessed through the existing tracker."
}

variable "observability_atracker_target_type" {
  type        = string
  default     = "cloudlogs"
  description = "Determines where all events can be stored based on the user input. Select the desired target type to retrieve or capture events into your system."
  validation {
    condition     = contains(["cloudlogs", "cos"], var.observability_atracker_target_type)
    error_message = "Allowed values for atracker target type is cloudlogs and cos."
  }
}

variable "cos_expiration_days" {
  type        = number
  default     = 30
  description = "Specify the retention period for objects in COS buckets by setting the number of days after their creation for automatic expiration. This configuration helps manage storage efficiently by removing outdated or unnecessary data, reducing storage costs, and maintaining data lifecycle policies. Ensure that the specified duration aligns with your data retention and compliance requirements."
}

variable "enable_vpc_flow_logs" {
  type        = bool
  default     = true
  description = "This flag determines whether VPC flow logs are enabled. When set to true, a flow log collector will be created to capture and monitor network traffic data within the VPC. Enabling flow logs provides valuable insights for troubleshooting, performance monitoring, and security auditing by recording information about the traffic passing through your VPC. Consider enabling this feature to enhance visibility and maintain robust network management practices."
}

variable "vpn_enabled" {
  type        = bool
  default     = false
  description = "Set the value as true to deploy a VPN gateway for VPC in the cluster."
}

variable "observability_monitoring_enable" {
  description = "Set this value as false to disable the IBM Cloud Monitoring integration. If enabled, infrastructure and LSF application metrics only from management nodes will be captured."
  type        = bool
  default     = true
}

variable "observability_logs_enable_for_management" {
  description = "Set this value as false to disable the IBM Cloud Logs integration. If enabled, infrastructure and LSF application logs from management nodes will be captured."
  type        = bool
  default     = false
}

variable "observability_logs_enable_for_compute" {
  description = "Set this value as false to disables the IBM Cloud Logs integration. If enabled, infrastructure and LSF application logs from compute nodes (static nodes or worker nodes) will be captured."
  type        = bool
  default     = false
}

variable "observability_enable_platform_logs" {
  description = "Setting this value as true creates a tenant in the same region in which the IBM® Cloud Logs instance is provisioned to enable platform logs for that region. NOTE: You can only have 1 tenant per region in an account."
  type        = bool
  default     = false
}

variable "observability_enable_metrics_routing" {
  description = "Enable the metrics routing to manage metrics at the account level by configuring targets and routes that define how the data points are routed."
  type        = bool
  default     = false
}

variable "observability_logs_retention_period" {
  description = "The number of days IBM Cloud Logs retains the logs data in priority insights. By default the value is set as 7, but the allowed values are 14, 30, 60, and 90."
  type        = number
  default     = 7
  validation {
    condition     = contains([7, 14, 30, 60, 90], var.observability_logs_retention_period)
    error_message = "Allowed values for cloud logs retention period is 7, 14, 30, 60, 90."
  }
}

variable "observability_monitoring_on_compute_nodes_enable" {
  description = "Set this value as false to disable IBM Cloud Monitoring integration. If enabled, infrastructure metrics from both static and dynamic compute nodes will be captured."
  type        = bool
  default     = false
}

variable "observability_monitoring_plan" {
  description = "This is a type of service plan for IBM Cloud Monitoring instance. You can choose one of the following: lite or graduated-tier. For all details visit [IBM Cloud Monitoring Service Plans](https://cloud.ibm.com/docs/monitoring?topic=monitoring-service_plans)."
  type        = string
  default     = "graduated-tier"
  validation {
    condition     = can(regex("lite|graduated-tier", var.observability_monitoring_plan))
    error_message = "Please enter a valid plan for IBM Cloud Monitoring, for all details visit https://cloud.ibm.com/docs/monitoring?topic=monitoring-service_plans."
  }
}

##############################################################################
# Encryption Variables
##############################################################################

variable "key_management" {
  type        = string
  default     = "key_protect"
  description = "Set the value as key_protect to enable customer managed encryption for boot volume and file share. If the key_management is set as null, IBM Cloud resources will be always be encrypted through provider managed."
  validation {
    condition     = var.key_management == "null" || var.key_management == null || var.key_management == "key_protect"
    error_message = "key_management must be either 'null' or 'key_protect'."
  }
}

variable "kms_instance_name" {
  type        = string
  default     = null
  description = "Provide the name of the existing Key Protect instance associated with the Key Management Service. Note: To use existing kms_instance_name set key_management as key_protect. The name can be found under the details of the KMS, see [View key-protect ID](https://cloud.ibm.com/docs/key-protect?topic=key-protect-retrieve-instance-ID&interface=ui)."
}

variable "kms_key_name" {
  type        = string
  default     = null
  description = "Provide the existing kms key name that you want to use for the IBM Spectrum LSF cluster. Note: kms_key_name to be considered only if key_management value is set as key_protect.(for example kms_key_name: my-encryption-key)."
}

##############################################################################
# SCC Variables
##############################################################################

variable "scc_enable" {
  type        = bool
  default     = true
  description = "Flag to enable SCC instance creation. If true, an instance of SCC (Security and Compliance Center) will be created."
}

variable "scc_profile" {
  type        = string
  default     = "CIS IBM Cloud Foundations Benchmark v1.1.0"
  description = "Profile to be set on the SCC Instance (accepting empty, 'CIS IBM Cloud Foundations Benchmark v1.1.0' and 'IBM Cloud Framework for Financial Services')"
  validation {
    condition     = can(regex("^(|CIS IBM Cloud Foundations Benchmark v1.1.0|IBM Cloud Framework for Financial Services)$", var.scc_profile))
    error_message = "Provide SCC Profile Name to be used (accepting empty, 'CIS IBM Cloud Foundations Benchmark' and 'IBM Cloud Framework for Financial Services')."
  }
}

variable "scc_location" {
  description = "Location where the SCC instance is provisioned (possible choices 'us-south', 'eu-de', 'ca-tor', 'eu-es')"
  type        = string
  default     = "us-south"
  validation {
    condition     = can(regex("^(|us-south|eu-de|ca-tor|eu-es)$", var.scc_location))
    error_message = "Provide region where it's possible to deploy an SCC Instance (possible choices 'us-south', 'eu-de', 'ca-tor', 'eu-es') or leave blank and it will default to 'us-south'."
  }
}

variable "scc_event_notification_plan" {
  type        = string
  default     = "lite"
  description = "Event Notifications Instance plan to be used (it's used with S.C.C. instance), possible values 'lite' and 'standard'."
  validation {
    condition     = can(regex("^(|lite|standard)$", var.scc_event_notification_plan))
    error_message = "Provide Event Notification instance plan to be used (accepting 'lite' and 'standard', defaulting to 'lite'). This instance is used in conjuction with S.C.C. one."
  }
}

##############################################################################
# Hyper-Threading in Compute Nodes
##############################################################################

variable "hyperthreading_enabled" {
  type        = bool
  default     = true
  description = "Enabling this setting (true by default) allows hyper-threading on the nodes of the cluster, improving overall processing efficiency by permitting each CPU core to execute multiple threads simultaneously. If set to false, hyperthreading will be disabled, which may be preferable for certain workloads requiring dedicated, non-threaded CPU resources for optimal performance. Carefully consider the nature of your computational tasks when configuring this option to achieve the best balance between performance and resource utilization."
}

##############################################################################
# Encryption Variables
##############################################################################
variable "enable_app_center" {
  type        = bool
  default     = false
  description = "Set to true to enable the IBM Spectrum LSF Application Center GUI (default: false). [System requirements](https://www.ibm.com/docs/en/slac/10.2.0?topic=requirements-system-102-fix-pack-14) for IBM Spectrum LSF Application Center Version 10.2 Fix Pack 14."
}

variable "app_center_gui_pwd" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Password for IBM Spectrum LSF Application Center GUI. Note: Password should be at least 8 characters, must have one number, one lowercase letter, one uppercase letter, and at least one special character."
}

variable "app_center_high_availability" {
  type        = bool
  default     = false
  description = "Set to false to disable the IBM Spectrum LSF Application Center GUI High Availability (default: true). If the value is set as true, provide a certificate instance crn under existing_certificate_instance value for the VPC load balancer to enable HTTPS connections.For more information see [certificate instance requirements](https://cloud.ibm.com/docs/allowlist/hpc-service?topic=hpc-service-before-deploy-application-center)."
}

variable "enable_fip" {
  type        = bool
  default     = true
  description = "The solution supports multiple ways to connect to your IBM Spectrum LSF cluster. For example, using a login node, or using VPN or direct connection. If connecting to the lsf cluster using VPN or direct connection, set this value to false."
}

##############################################################################
# ldap Variables
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

variable "skip_iam_block_storage_authorization_policy" {
  type        = bool
  default     = false
  description = "When using an existing KMS instance name, set this value to true if authorization is already enabled between KMS instance and the block storage volume. Otherwise, default is set to false. Ensuring proper authorization avoids access issues during deployment.For more information on how to create authorization policy manually, see [creating authorization policies for block storage volume](https://cloud.ibm.com/docs/vpc?topic=vpc-block-s2s-auth&interface=ui)."
}

variable "skip_iam_share_authorization_policy" {
  type        = bool
  default     = false
  description = "When using an existing KMS instance name, set this value to true if authorization is already enabled between KMS instance and the VPC file share. Otherwise, default is set to false. Ensuring proper authorization avoids access issues during deployment.For more information on how to create authorization policy manually, see [creating authorization policies for VPC file share](https://cloud.ibm.com/docs/vpc?topic=vpc-file-s2s-auth&interface=ui)."
}

variable "skip_flowlogs_s2s_auth_policy" {
  type        = bool
  default     = false
  description = "When using an existing COS instance, set this value to true if authorization is already enabled between COS instance and the flow logs service. Otherwise, default is set to false. Ensuring proper authorization avoids access issues during deployment."
}

###########################################################################
# IBM Cloud ALB Variables
###########################################################################
variable "app_center_existing_certificate_instance" {
  description = "When app_center_high_availability is enable/set as true, The Application Center will be configured for high availability and requires a Application Load Balancer Front End listener to use a certificate CRN value stored in the Secret Manager. Provide the valid 'existing_certificate_instance' to configure the Application load balancer."
  type        = string
  default     = ""
}

##############################################################################
# Environment Variables
##############################################################################

# tflint-ignore: all
variable "TF_VERSION" {
  type        = string
  default     = "1.9"
  description = "The version of the Terraform engine that's used in the Schematics workspace."
}

# tflint-ignore: all
variable "TF_PARALLELISM" {
  type        = string
  default     = "250"
  description = "Parallelism/ concurrent operations limit. Valid values are between 1 and 256, both inclusive. [Learn more](https://www.terraform.io/docs/internals/graph.html#walking-the-graph)."
  validation {
    condition     = 1 <= var.TF_PARALLELISM && var.TF_PARALLELISM <= 256
    error_message = "Input \"TF_PARALLELISM\" must be greater than or equal to 1 and less than or equal to 256."
  }
}

# tflint-ignore: terraform_naming_convention
variable "TF_VALIDATION_SCRIPT_FILES" {
  type        = list(string)
  default     = []
  description = "List of script file names used by validation test suites. If provided, these scripts will be executed as part of validation test suites execution."
  validation {
    condition     = alltrue([for filename in var.TF_VALIDATION_SCRIPT_FILES : can(regex(".*\\.sh$", filename))])
    error_message = "All validation script file names must end with .sh."
  }
}
###########################################################################
# Existing Bastion Support variables
###########################################################################

variable "existing_bastion_instance_name" {
  type        = string
  default     = null
  description = "Provide the name of the bastion instance. If none given then new bastion will be created."
}

variable "existing_bastion_instance_public_ip" {
  type        = string
  default     = null
  description = "Provide the public ip address of the bastion instance to establish the remote connection."
}

variable "existing_bastion_security_group_id" {
  type        = string
  default     = null
  description = "Specify the security group ID for the bastion server. This ID will be added as an allowlist rule on the HPC cluster nodes to facilitate secure SSH connections through the bastion node. By restricting access through a bastion server, this setup enhances security by controlling and monitoring entry points into the cluster environment. Ensure that the specified security group is correctly configured to permit only authorized traffic for secure and efficient management of cluster resources."
}

variable "existing_bastion_ssh_private_key" {
  type        = string
  sensitive   = true
  default     = null
  description = "Provide the private SSH key (named id_rsa) used during the creation and configuration of the bastion server to securely authenticate and connect to the bastion server. This allows access to internal network resources from a secure entry point. Note: The corresponding public SSH key (named id_rsa.pub) must already be available in the ~/.ssh/authorized_keys file on the bastion host to establish authentication."
}

###########################################################################
# Dedicated Host variables
###########################################################################

variable "enable_dedicated_host" {
  type        = bool
  default     = false
  description = "Set this option to true to enable dedicated hosts for the VSI created for workload servers. The default value is false. When a dedicated host is enabled, the solution supports only static worker nodes with a single profile, and multiple profile combinations are not supported. For example, you can select a profile from a single family, such as bx2, cx2, or mx2. If you are provisioning a static cluster with a third-generation profile, ensure that dedicated hosts are supported in the chosen regions, as not all regions support dedicated hosts for third-gen profiles. To learn more about dedicated host, [click here.](https://cloud.ibm.com/docs/vpc?topic=vpc-dh-profiles&interface=ui)"
  validation {
    condition     = !(var.enable_dedicated_host && length(var.worker_node_instance_type) != 1)
    error_message = "When 'enable_dedicated_host' is true, only one profile should be specified in 'worker_node_instance_type'."
  }
}
