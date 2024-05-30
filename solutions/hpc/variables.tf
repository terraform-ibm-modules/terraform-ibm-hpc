##############################################################################
# Account Variables
##############################################################################

variable "ibmcloud_api_key" {
  description = "IBM Cloud API key for the IBM Cloud account where the IBM Cloud HPC cluster needs to be deployed. For more information on how to create an API key, see [Managing user API keys](https://cloud.ibm.com/docs/account?topic=account-userapikey)."
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

variable "resource_group" {
  description = "Resource group name from your IBM Cloud account where the VPC resources should be deployed. Note. If the resource group value is set as null, automation creates two different RG with the name (workload-rg and service-rg). For additional information on resource groups, see [Managing resource groups](https://cloud.ibm.com/docs/account?topic=account-rgs)."
  type        = string
  default     = "Default"
  validation {
    condition     = var.resource_group != null
    error_message = "If you want to provide null for resource_group variable, it should be within double quotes."
  }
}

##############################################################################
# Module Level Variables
##############################################################################

variable "cluster_prefix" {
  description = "Prefix that is used to name the IBM Cloud HPC cluster and IBM Cloud resources that are provisioned to build the IBM Cloud HPC cluster instance. You cannot create more than one instance of the IBM Cloud HPC cluster with the same name. Ensure that the name is unique. Prefix must start with a lowercase letter and contain only lowercase letters, digits, and hyphens in between. Hyphens must be followed by at least one lowercase letter or digit. There are no leading, trailing, or consecutive hyphens.Character length for cluster_prefix should be less than 16."
  type        = string
  default     = "hpcaas"

  validation {
    error_message = "Prefix must start with a lowercase letter and contain only lowercase letters, digits, and hyphens in between. Hyphens must be followed by at least one lowercase letter or digit. There are no leading, trailing, or consecutive hyphens."
    condition     = can(regex("^[a-z](?:[a-z0-9]*(-[a-z0-9]+)*)?$", var.cluster_prefix))
  }
  validation {
    condition     = length(var.cluster_prefix) <= 16
    error_message = "The cluster_prefix must be 16 characters or fewer."
  }
}

variable "zones" {
  description = "The IBM Cloud zone name within the selected region where the IBM Cloud HPC cluster should be deployed and requires a single zone input value. Supported zones are: eu-de-2 and eu-de-3 for eu-de, us-east-1 and us-east-3 for us-east, and us-south-1 for us-south. The management nodes, file storage shares, and compute nodes will be deployed in the same zone.[Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region#get-zones-using-the-cli)."
  type        = list(string)
  default     = ["us-east-1"]
  validation {
    condition     = length(var.zones) == 1
    error_message = "HPC product deployment supports only a single zone. Provide a value for a single zone from the supported regions: eu-de-2 or eu-de-3 for eu-de, us-east-1 or us-east-3 for us-east, and us-south-1 for us-south."
  }
}

variable "cluster_id" {
  type        = string
  description = "Ensure that you have received the cluster ID from IBM technical sales. A unique identifer for HPC cluster used by IBM Cloud HPC to differentiate different HPC clusters within the same reservations. This can be up to 39 alphanumeric characters including the underscore (_), the hyphen (-), and the period (.) characters. You cannot change the cluster ID after deployment."
  validation {
    condition     = 0 < length(var.cluster_id) && length(var.cluster_id) < 40 && can(regex("^[a-zA-Z0-9_.-]+$", var.cluster_id))
    error_message = "The ID can be up to 39 alphanumeric characters including the underscore (_), the hyphen (-), and the period (.) characters. Other special characters and spaces are not allowed."
  }
}

variable "reservation_id" {
  type        = string
  sensitive   = true
  description = "Ensure that you have received the reservation ID from IBM technical sales. Reservation ID is a unique identifier to distinguish different IBM Cloud HPC service agreements. It must start with a letter and can only contain letters, numbers, hyphens (-), or underscores (_)."
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-_]*$", var.reservation_id))
    error_message = "Reservation ID must start with a letter and can only contain letters, numbers, hyphens (-), or underscores (_)."
  }
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
  description = "Provide the list of existing subnet ID under the existing VPC where the cluster will be provisioned. One subnet ID is required as input value. Supported zones are: eu-de-2 and eu-de-3 for eu-de, us-east-1 and us-east-3 for us-east, and us-south-1 for us-south. The management nodes, file storage shares, and compute nodes will be deployed in the same zone."
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
  description = "Comma-separated list of IP addresses that can access the IBM Cloud HPC cluster instance through an SSH interface. For security purposes, provide the public IP addresses assigned to the devices that are authorized to establish SSH connections (for example, [\"169.45.117.34\"]). To fetch the IP address of the device, use [https://ipv4.icanhazip.com/](https://ipv4.icanhazip.com/)."
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
  description = "Provide the list of SSH key names configured in your IBM Cloud account to establish a connection to the IBM Cloud HPC bastion and login node. Ensure the SSH key is present in the same resource group and region where the cluster is being provisioned. If you do not have an SSH key in your IBM Cloud account, create one by following the provided instructions.[SSH Keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
}

variable "compute_ssh_keys" {
  type        = list(string)
  description = "Provide the list of SSH key names configured in your IBM Cloud account to establish a connection to the IBM Cloud HPC cluster node. Ensure the SSH key is present in the same resource group and region where the cluster is being provisioned. If you do not have an SSH key in your IBM Cloud account, create one by following the provided instructions.[SSH Keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys)."
}

variable "login_node_instance_type" {
  type        = string
  default     = "bx2-2x8"
  description = "Specify the virtual server instance profile type to be used to create the login node for the IBM Cloud HPC cluster. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  validation {
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.login_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}
variable "management_image_name" {
  type        = string
  default     = "hpcaas-lsf10-rhel88-v6"
  description = "Name of the custom image that you want to use to create virtual server instances in your IBM Cloud account to deploy the IBM Cloud HPC cluster management nodes. By default, the solution uses a RHEL88 base image with additional software packages mentioned [here](https://cloud.ibm.com/docs/ibm-spectrum-lsf#create-custom-image). If you would like to include your application-specific binary files, follow the instructions in [ Planning for custom images ](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the IBM Cloud HPC cluster through this offering."

}

variable "compute_image_name" {
  type        = string
  default     = "hpcaas-lsf10-rhel88-compute-v5"
  description = "Name of the custom image that you want to use to create virtual server instances in your IBM Cloud account to deploy the IBM Cloud HPC cluster dynamic compute nodes. By default, the solution uses a RHEL 8-8 base OS image with additional software packages mentioned [here](https://cloud.ibm.com/docs/ibm-spectrum-lsf#create-custom-image). The solution also offers, Ubuntu 22-04 OS base image (hpcaas-lsf10-ubuntu2204-compute-v4). If you would like to include your application-specific binary files, follow the instructions in [ Planning for custom images ](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the IBM Cloud HPC cluster through this offering."
}

variable "login_image_name" {
  type        = string
  default     = "hpcaas-lsf10-rhel88-compute-v5"
  description = "Name of the custom image that you want to use to create virtual server instances in your IBM Cloud account to deploy the IBM Cloud HPC cluster login node. By default, the solution uses a RHEL 8-8 OS image with additional software packages mentioned [here](https://cloud.ibm.com/docs/ibm-spectrum-lsf#create-custom-image). The solution also offers, Ubuntu 22-04 OS base image (hpcaas-lsf10-ubuntu2204-compute-v4). If you would like to include your application-specific binary files, follow the instructions in [ Planning for custom images ](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the IBM Cloud HPC cluster through this offering."
}

variable "management_node_instance_type" {
  type        = string
  default     = "bx2-16x64"
  description = "Specify the virtual server instance profile type to be used to create the management nodes for the IBM Cloud HPC cluster. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
  validation {
    condition     = can(regex("^[^\\s]+-[0-9]+x[0-9]+", var.management_node_instance_type))
    error_message = "The profile must be a valid profile name."
  }
}

variable "management_node_count" {
  type        = number
  default     = 3
  description = "Number of management nodes. This is the total number of management nodes. Enter a value between 1 and 10."
  validation {
    condition     = 1 <= var.management_node_count && var.management_node_count <= 10
    error_message = "Input \"management_node_count\" must be must be greater than or equal to 1 and less than or equal to 10."
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
  description = "Mount points and sizes in GB and IOPS range of file shares that can be used to customize shared file storage layout. Provide the details for up to 5 shares. Each file share size in GB supports different range of IOPS. For more information, see [file share IOPS value](https://cloud.ibm.com/docs/vpc?topic=vpc-file-storage-profiles&interface=ui)."
  validation {
    condition     = length([for item in var.custom_file_shares : item if item.nfs_share == null]) <= 5
    error_message = "The VPC storage custom file share count \"custom_file_shares\" must be less than or equal to 5. Unlimited NFS mounts are allowed."
  }
  validation {
    condition     = !anytrue([for mounts in var.custom_file_shares : mounts.mount_path == "/mnt/lsf"])
    error_message = "The mount path /mnt/lsf is reserved for internal usage and can't be used as file share mount_path."
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
  description = "Provide the storage security group ID created from the Spectrum Scale storage cluster if the nfs_share value is updated to use the scale fileset mountpoints under the cluster_file_share variable."
}

##############################################################################
# DNS Template Variables
##############################################################################

variable "dns_instance_id" {
  type        = string
  default     = null
  description = "Provide the id of existing IBM Cloud DNS services domain to skip creating a new DNS service instance name. Note: If dns_instance_id is not equal to null, a new dns zone will be created under the existing dns service instance."
}

variable "dns_domain_name" {
  type = object({
    compute = string
    #storage  = string
    #protocol = string
  })
  default = {
    compute = "hpcaas.com"
  }
  description = "IBM Cloud DNS Services domain name to be used for the IBM Cloud HPC cluster."
  validation {
    condition = can(regex("^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9])\\.com$", var.dns_domain_name.compute))
    #condition = can(regex("^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\\.)+[a-zA-Z]{2,6}$", var.dns_domain_names.compute))
    #condition = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.[a-zA-Z]{2,6}$", var.dns_domain_names.compute))
    #condition     = can(regex("^([[:alnum:]]*[A-Za-z0-9-]{1,63}\\.)+[A-Za-z]{2,6}$", var.dns_domain_names.compute))
    error_message = "The domain name provided for compute is not a fully qualified domain name (FQDN). An FQDN can contain letters (a-z, A-Z), digits (0-9), hyphens (-), dots (.), and must start and end with an alphanumeric character."
  }
}

variable "dns_custom_resolver_id" {
  type        = string
  default     = null
  description = "Provide the id of existing IBM Cloud DNS custom resolver to skip creating a new custom resolver. Note: A VPC can be associated only to a single custom resolver, please provide the id of custom resolver if it is already associated to the VPC."
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
  description = "Provide the name of the existing cos instance to store vpc flow logs."
}

variable "observability_atracker_on_cos_enable" {
  type        = bool
  default     = true
  description = "Enable Activity tracker service instance connected to Cloud Object Storage (COS). All the events will be stored into COS so that customers can connect to it and read those events or ingest them in their system."
}

variable "enable_vpc_flow_logs" {
  type        = bool
  default     = false
  description = "Flag to enable VPC flow logs. If true, a flow log collector will be created."
}

variable "vpn_enabled" {
  type        = bool
  default     = false
  description = "Set the value as true to deploy a VPN gateway for VPC in the cluster."
}

variable "observability_monitoring_enable" {
  description = "Set false to disable IBM Cloud Monitoring integration. If enabled, infrastructure and LSF application metrics from Management Nodes will be ingested."
  type        = bool
  default     = false
}

variable "observability_monitoring_on_compute_nodes_enable" {
  description = "Set false to disable IBM Cloud Monitoring integration. If enabled, infrastructure metrics from Compute Nodes will be ingested."
  type        = bool
  default     = false
}

variable "observability_monitoring_plan" {
  description = "Type of service plan for IBM Cloud Monitoring instance. You can choose one of the following: lite, graduated-tier. For all details visit [IBM Cloud Monitoring Service Plans](https://cloud.ibm.com/docs/monitoring?topic=monitoring-service_plans)."
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
  description = "Set the value as key_protect to enable customer managed encryption for boot volume and file share. If the key_management is set as null, encryption will be always provider managed."
  validation {
    condition     = var.key_management == "null" || var.key_management == null || var.key_management == "key_protect"
    error_message = "key_management must be either 'null' or 'key_protect'."
  }
}

variable "kms_instance_name" {
  type        = string
  default     = null
  description = "Provide the name of the existing Key Protect instance associated with the Key Management Service. Note: To use existing kms_instance_name shall be considered only if key_management value is set as key_protect under key_management variable. The name can be found under the details of the KMS, see [View key-protect ID](https://cloud.ibm.com/docs/key-protect?topic=key-protect-retrieve-instance-ID&interface=ui)."
}

variable "kms_key_name" {
  type        = string
  default     = null
  description = "Provide the existing KMS encryption key name that you want to use for the IBM Cloud HPC cluster. Note: kms_key_name to be considered only if key_management value is set as key_protect under key_management variable.(for example kms_key_name: my-encryption-key)."
}

##############################################################################
# SCC Variables
##############################################################################

variable "scc_enable" {
  type        = bool
  default     = false
  description = "Flag to enable SCC instance creation. If true, an instance of SCC (Security and Compliance Center) will be created."
}

variable "scc_profile" {
  type        = string
  default     = "CIS IBM Cloud Foundations Benchmark"
  description = "Profile to be set on the SCC Instance (accepting empty, 'CIS IBM Cloud Foundations Benchmark' and 'IBM Cloud Framework for Financial Services')"
  validation {
    condition     = can(regex("^(|CIS IBM Cloud Foundations Benchmark|IBM Cloud Framework for Financial Services)$", var.scc_profile))
    error_message = "Provide SCC Profile Name to be used (accepting empty, 'CIS IBM Cloud Foundations Benchmark' and 'IBM Cloud Framework for Financial Services')."
  }
}

variable "scc_profile_version" {
  type        = string
  default     = "1.0.0"
  description = "Version of the Profile to be set on the SCC Instance (accepting empty, CIS and Financial Services profiles versions)"
  validation {
    condition     = can(regex("^(|\\d+\\.\\d+(\\.\\d+)?)$", var.scc_profile_version))
    error_message = "Provide SCC Profile Version to be used."
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
  description = "Setting this to true will enable hyper-threading in the compute nodes of the cluster (default). Otherwise, hyper-threading will be disabled."
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
  default     = true
  description = "Set to false to disable the IBM Spectrum LSF Application Center GUI High Availability (default: true)."
}

variable "enable_fip" {
  type        = bool
  default     = true
  description = "The solution supports multiple ways to connect to your IBM Cloud HPC cluster for example, using a login node, or using VPN or direct connection. If connecting to the IBM Cloud HPC cluster using VPN or direct connection, set this value to false."
}

##############################################################################
# ldap Variables
##############################################################################
variable "enable_ldap" {
  type        = bool
  default     = false
  description = "Set this option to true to enable LDAP for IBM Cloud HPC, with the default value set to false."
}

variable "ldap_basedns" {
  type        = string
  default     = "hpcaas.com"
  description = "The dns domain name is used for configuring the LDAP server. If an LDAP server is already in existence, ensure to provide the associated DNS domain name."
}

variable "ldap_server" {
  type        = string
  default     = "null"
  description = "Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created."
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
  description = "Specify the virtual server instance profile type to be used to create the ldap node for the IBM Cloud HPC cluster. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles)."
}

variable "ldap_vsi_osimage_name" {
  type        = string
  default     = "ibm-ubuntu-22-04-3-minimal-amd64-1"
  description = "Image name to be used for provisioning the LDAP instances. By default ldap server are created on Ubuntu based OS flavour."
}

variable "skip_iam_authorization_policy" {
  type        = string
  default     = false
  description = "Set it to false if authorization policy is required for VPC to access COS. This can be set to true if authorization policy already exists. For more information on how to create authorization policy manually, see [creating authorization policies for VPC flow log](https://cloud.ibm.com/docs/vpc?topic=vpc-ordering-flow-log-collector&interface=ui#fl-before-you-begin-ui)."
}

###########################################################################
# IBM Cloud ALB Variables
###########################################################################
variable "existing_certificate_instance" {
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
  default     = "1.5"
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

variable "bastion_instance_name" {
  type        = string
  default     = null
  description = "Bastion instance name. If none given then new bastion will be created."
}

variable "bastion_instance_public_ip" {
  type        = string
  default     = null
  description = "Bastion instance public ip address."
}

variable "bastion_security_group_id" {
  type        = string
  default     = null
  description = "Bastion security group id."
}

variable "bastion_ssh_private_key" {
  type        = string
  sensitive   = true
  default     = null
  description = "Bastion SSH private key path, which will be used to login to bastion host."
}
