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

# Delete this variable before pushing to the public repository.
variable "github_token" {
  type        = string
  default     = null
  description = "Provide your GitHub token to download the HPCaaS code into the Deployer node"
}

variable "lsf_version" {
  type        = string
  default     = "fixpack_15"
  description = "Select the LSF version to deploy: 'fixpack_14' or 'fixpack_15'."

  validation {
    condition     = contains(["fixpack_14", "fixpack_15"], var.lsf_version)
    error_message = "Invalid LSF version. Allowed values are 'fixpack_14' and 'fixpack_15'"
  }
}

##############################################################################
# Cluster Level Variables
##############################################################################
variable "zones" {
  description = "Specify the IBM Cloud zone within the chosen region where the IBM Spectrum LSF cluster will be deployed. A single zone input is required, and the management nodes, file storage shares, and compute nodes will all be provisioned in this zone.[Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region#get-zones-using-the-cli)."
  type        = list(string)
  default     = ["us-east-1"]
  validation {
    condition     = length(var.zones) == 1
    error_message = "HPC product deployment supports only a single zone. Provide a value for a single zone from the supported regions: eu-de-2 or eu-de-3 for eu-de, us-east-1 or us-east-3 for us-east, and us-south-1 for us-south."
  }
}

variable "ssh_keys" {
  type        = list(string)
  default     = null
  description = "The key pair to use to access the HPC cluster."
}

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
# VPC Variables
##############################################################################
variable "vpc_name" {
  type        = string
  default     = null
  description = "Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.241.0.0/18"
  description = "Network CIDR for the VPC. This is used to manage network ACL rules for cluster provisioning."
}

# variable "placement_strategy" {
#   type        = string
#   default     = null
#   description = "VPC placement groups to create (null / host_spread / power_spread)"
# }

##############################################################################
# Access Variables
##############################################################################
variable "enable_bastion" {
  type        = bool
  default     = true
  description = "The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN or direct connection, set this value to false."
}

variable "bastion_image" {
  type        = string
  default     = "ibm-ubuntu-22-04-3-minimal-amd64-1"
  description = "The image to use to deploy the bastion host."
}

variable "bastion_instance_profile" {
  type        = string
  default     = "cx2-4x8"
  description = "Deployer should be only used for better deployment performance"
}

variable "vpc_cluster_login_private_subnets_cidr_blocks" {
  type        = string
  default     = "10.241.16.0/28"
  description = "Provide the CIDR block required for the creation of the login cluster's private subnet. Only one CIDR block is needed. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Since the login subnet is used only for the creation of login virtual server instances, provide a CIDR range of /28."
  validation {
    condition     = tonumber(regex("^.*?/(\\d+)$", var.vpc_cluster_login_private_subnets_cidr_blocks)[0]) <= 28
    error_message = "This subnet is used to create only a login virtual server instance. Providing a larger CIDR size will waste the usage of available IPs. A CIDR range of /28 is sufficient for the creation of the login subnet."
  }
}

variable "login_subnet_id" {
  type        = string
  default     = null
  description = "Name of an existing subnets in which the cluster resources will be deployed. If no value is given, then new subnet(s) will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc)"
}

##############################################################################
# Deployer Variables
##############################################################################
variable "deployer_image" {
  type        = string
  default     = "jay-lsf-new-image"
  description = "The image to use to deploy the deployer host."
}

variable "deployer_instance_profile" {
  type        = string
  default     = "bx2-8x32"
  description = "Deployer should be only used for better deployment performance"
}

##############################################################################
# Compute Variables
#############################################################################

variable "vpc_cluster_private_subnets_cidr_blocks" {
  type        = string
  default     = "10.241.0.0/20"
  description = "Provide the CIDR block required for the creation of the compute cluster's private subnet. One CIDR block is required. If using a hybrid environment, modify the CIDR block to avoid conflicts with any on-premises CIDR blocks. Ensure the selected CIDR block size can accommodate the maximum number of management and dynamic compute nodes expected in your cluster. For more information on CIDR block size selection, refer to the documentation, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc)."
}

variable "cluster_subnet_ids" {
  type        = string
  default     = null
  description = "Provide the list of existing subnet ID under the existing VPC where the cluster will be provisioned. One subnet ID is required as input value. The management nodes, file storage shares, and compute nodes will be deployed in the same zone."
}

variable "management_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  default = [{
    profile = "cx2-2x4"
    count   = 2
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "Number of instances to be launched for management."
}

variable "static_compute_instances" {
  type = list(
    object({
      profile    = string
      count      = number
      image      = string
      filesystem = string
    })
  )
  default = [{
    profile    = "cx2-2x4"
    count      = 1
    image      = "ibm-redhat-8-10-minimal-amd64-2"
    filesystem = "/gpfs/fs1"
  }]
  description = "Min Number of instances to be launched for compute cluster."
}

variable "dynamic_compute_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  default = [{
    profile = "cx2-2x4"
    count   = 1024
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "MaxNumber of instances to be launched for compute cluster."
}

variable "compute_gui_username" {
  type        = string
  default     = "admin"
  sensitive   = true
  description = "GUI user to perform system management and monitoring tasks on compute cluster."
}

variable "compute_gui_password" {
  type        = string
  default     = "hpc@IBMCloud"
  sensitive   = true
  description = "Password for compute cluster GUI"
}

# variable "cluster_name" {
#   type        = string
#   default     = "HPCCluster"
#   description = "Unique ID of the cluster used by LSF for configuration of resources. This can be up to 39 alphanumeric characters."
#   validation {
#     condition     = 0 < length(var.cluster_name) && length(var.cluster_name) < 40 && can(regex("^[a-zA-Z0-9_.-]+$", var.cluster_name))
#     error_message = "The ID can be up to 39 alphanumeric characters including the underscore (_), the hyphen (-), and the period (.) characters."
#   }
# }

variable "enable_hyperthreading" {
  type        = bool
  default     = true
  description = "Setting this to true will enable hyper-threading in the worker nodes of the cluster (default). Otherwise, hyper-threading will be disabled."
}

# variable "enable_dedicated_host" {
#   type        = bool
#   default     = false
#   description = "Set to true to use dedicated hosts for compute hosts (default: false)."
# }

# variable "dedicated_host_placement" {
#   type        = string
#   default     = "spread"
#   description = "Specify 'pack' or 'spread'. The 'pack' option will deploy VSIs on one dedicated host until full before moving on to the next dedicated host."
#   validation {
#     condition     = var.dedicated_host_placement == "spread" || var.dedicated_host_placement == "pack"
#     error_message = "Supported values for dedicated_host_placement: spread or pack."
#   }
# }

# variable "enable_app_center" {
#   type        = bool
#   default     = false
#   description = "Set to true to install and enable use of the IBM Spectrum LSF Application Center GUI."
# }

# variable "app_center_gui_password" {
#   type        = string
#   default     = "hpc@IBMCloud"
#   sensitive   = true
#   description = "Password for IBM Spectrum LSF Application Center GUI."
# }

# variable "app_center_db_password" {
#   type        = string
#   default     = "hpc@IBMCloud"
#   sensitive   = true
#   description = "Password for IBM Spectrum LSF Application Center database GUI."
# }

##############################################################################
# Storage Scale Variables
##############################################################################
variable "storage_subnets_cidr" {
  type        = string
  default     = "10.241.30.0/24"
  description = "Subnet CIDR block to launch the storage cluster host."
}

variable "storage_instances" {
  type = list(
    object({
      profile    = string
      count      = number
      image      = string
      filesystem = string
    })
  )
  default = [{
    profile    = "bx2d-2x8"
    count      = 0
    image      = "ibm-redhat-8-10-minimal-amd64-2"
    filesystem = "fs1"
  }]
  description = "Number of instances to be launched for storage cluster."
}

variable "storage_servers" {
  type = list(
    object({
      profile    = string
      count      = number
      image      = string
      filesystem = string
    })
  )
  default = [{
    profile    = "cx2d-metal-96x192"
    count      = 0
    image      = "ibm-redhat-8-10-minimal-amd64-4"
    filesystem = "/gpfs/fs1"
  }]
  description = "Number of BareMetal Servers to be launched for storage cluster."
}

variable "protocol_subnets_cidr" {
  type        = string
  default     = "10.241.40.0/24"
  description = "Subnet CIDR block to launch the storage cluster host."
}

variable "protocol_instances" {
  type = list(
    object({
      profile = string
      count   = number
      image   = string
    })
  )
  default = [{
    profile = "bx2-2x8"
    count   = 0
    image   = "ibm-redhat-8-10-minimal-amd64-2"
  }]
  description = "Number of instances to be launched for protocol hosts."
}

# variable "colocate_protocol_instances" {
#   type        = bool
#   default     = true
#   description = "Enable it to use storage instances as protocol instances"
# }

variable "storage_gui_username" {
  type        = string
  default     = "admin"
  sensitive   = true
  description = "GUI user to perform system management and monitoring tasks on storage cluster."
}

variable "storage_gui_password" {
  type        = string
  default     = "hpc@IBMCloud"
  sensitive   = true
  description = "Password for storage cluster GUI"
}

variable "storage_security_group_id" {
  type        = string
  default     = null
  description = "Provide the storage security group ID from the Spectrum Scale storage cluster if the mount_path in the cluster_file_share variable is set to use Scale fileset mount points. This security group is essential for establishing connections between the Spectrum LSF cluster nodes and NFS mount points, ensuring the nodes can access the specified mount points."
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

##############################################################################
# DNS Variables
##############################################################################

variable "dns_instance_id" {
  type        = string
  default     = null
  description = "Provide the ID of an existing IBM Cloud DNS service instance to avoid creating a new one. Note: If dns_instance_id is not set to null, a new DNS zone will be created within the specified DNS service instance."
}

variable "dns_custom_resolver_id" {
  type        = string
  default     = null
  description = "IBM Cloud DNS custom resolver id."
}

variable "dns_domain_names" {
  type = object({
    compute  = string
    storage  = string
    protocol = string
    client   = string
    gklm     = string
  })
  default = {
    compute  = "comp.com"
    storage  = "strg.com"
    protocol = "ces.com"
    client   = "clnt.com"
    gklm     = "gklm.com"
  }
  description = "IBM Cloud HPC DNS domain names."
  validation {
    condition     = alltrue([for d in [var.dns_domain_names.compute, var.dns_domain_names.storage, var.dns_domain_names.protocol, var.dns_domain_names.client, var.dns_domain_names.gklm] : can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.com$", d))])
    error_message = "The domain name provided for compute is not a fully qualified domain name (FQDN). An FQDN can contain letters (a-z, A-Z), digits (0-9), hyphens (-), dots (.), and must start and end with an alphanumeric character."
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
  description = "Provide the existing kms key name that you want to use for the IBM Cloud HPC cluster. Note: kms_key_name to be considered only if key_management value is set as key_protect.(for example kms_key_name: my-encryption-key)."
}

variable "skip_iam_share_authorization_policy" {
  type        = bool
  default     = false
  description = "When using an existing KMS instance name, set this value to true if authorization is already enabled between KMS instance and the VPC file share. Otherwise, default is set to false. Ensuring proper authorization avoids access issues during deployment.For more information on how to create authorization policy manually, see [creating authorization policies for VPC file share](https://cloud.ibm.com/docs/vpc?topic=vpc-file-s2s-auth&interface=ui)."
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
  default     = null
  description = "Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created."
}

variable "ldap_server_cert" {
  type        = string
  sensitive   = true
  default     = null
  description = "Provide the existing LDAP server certificate. This value is required if the 'ldap_server' variable is not set to null. If the certificate is not provided or is invalid, the LDAP configuration may fail. For more information on how to create or obtain the certificate, please refer [existing LDAP server certificate](https://cloud.ibm.com/docs/allowlist/hpc-service?topic=hpc-service-integrating-openldap)."
}

variable "ldap_admin_password" {
  type        = string
  sensitive   = true
  default     = null
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

variable "ldap_instances" {
  type = list(
    object({
      profile = string
      image   = string
    })
  )
  default = [{
    profile = "cx2-2x4"
    image   = "ibm-ubuntu-22-04-5-minimal-amd64-1"
  }]
  description = "Profile and Image name to be used for provisioning the LDAP instances. Note: Debian based OS are only supported for the LDAP feature"
}

variable "vpn_enabled" {
  type        = bool
  default     = false
  description = "Set the value as true to deploy a VPN gateway for VPC in the cluster."
}

##############################################################################
# Observability Variables
##############################################################################
variable "enable_cos_integration" {
  type        = bool
  default     = true
  description = "Integrate COS with HPC solution"
}

variable "cos_instance_name" {
  type        = string
  default     = null
  description = "Exiting COS instance name"
}

variable "enable_vpc_flow_logs" {
  type        = bool
  default     = true
  description = "Enable Activity tracker"
}

##############################################################################
# Observability Variables
##############################################################################

variable "observability_atracker_enable" {
  type        = bool
  default     = true
  description = "Activity Tracker Event Routing to configure how to route auditing events. While multiple Activity Tracker instances can be created, only one tracker is needed to capture all events. Creating additional trackers is unnecessary if an existing Activity Tracker is already integrated with a COS bucket. In such cases, set the value to false, as all events can be monitored and accessed through the existing Activity Tracker."
}

variable "observability_atracker_target_type" {
  type        = string
  default     = "cloudlogs"
  description = "All the events will be stored in either COS bucket or Cloud Logs on the basis of user input, so customers can retrieve or ingest them in their system."
  validation {
    condition     = contains(["cloudlogs", "cos"], var.observability_atracker_target_type)
    error_message = "Allowed values for atracker target type is cloudlogs and cos."
  }
}

variable "observability_monitoring_enable" {
  description = "Set false to disable IBM Cloud Monitoring integration. If enabled, infrastructure and LSF application metrics from Management Nodes will be ingested."
  type        = bool
  default     = true
}

variable "observability_logs_enable_for_management" {
  description = "Set false to disable IBM Cloud Logs integration. If enabled, infrastructure and LSF application logs from Management Nodes will be ingested."
  type        = bool
  default     = false
}

variable "observability_logs_enable_for_compute" {
  description = "Set false to disable IBM Cloud Logs integration. If enabled, infrastructure and LSF application logs from Compute Nodes will be ingested."
  type        = bool
  default     = false
}

variable "observability_enable_platform_logs" {
  description = "Setting this to true will create a tenant in the same region that the Cloud Logs instance is provisioned to enable platform logs for that region. NOTE: You can only have 1 tenant per region in an account."
  type        = bool
  default     = false
}

variable "observability_enable_metrics_routing" {
  description = "Enable metrics routing to manage metrics at the account-level by configuring targets and routes that define where data points are routed."
  type        = bool
  default     = false
}

variable "observability_logs_retention_period" {
  description = "The number of days IBM Cloud Logs will retain the logs data in Priority insights. Allowed values: 7, 14, 30, 60, 90."
  type        = number
  default     = 7
  validation {
    condition     = contains([7, 14, 30, 60, 90], var.observability_logs_retention_period)
    error_message = "Allowed values for cloud logs retention period is 7, 14, 30, 60, 90."
  }
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
  description = "Profile to be set on the SCC Instance (accepting empty, 'CIS IBM Cloud Foundations Benchmark' and 'IBM Cloud Framework for Financial Services')"
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

variable "skip_flowlogs_s2s_auth_policy" {
  type        = bool
  default     = false
  description = "Skip auth policy between flow logs service and COS instance, set to true if this policy is already in place on account."
}

variable "skip_kms_s2s_auth_policy" {
  type        = bool
  default     = false
  description = "Skip auth policy between KMS service and COS instance, set to true if this policy is already in place on account."
}

variable "skip_iam_authorization_policy" {
  type        = bool
  default     = true
  description = "Set to false if authorization policy is required for VPC block storage volumes to access kms. This can be set to true if authorization policy already exists. For more information on how to create authorization policy manually, see [creating authorization policies for block storage volume](https://cloud.ibm.com/docs/vpc?topic=vpc-block-s2s-auth&interface=ui)."
}

##############################################################################
# Override JSON
##############################################################################
variable "override" {
  type        = bool
  default     = false
  description = "Override default values with custom JSON template. This uses the file `override.json` to allow users to create a fully customized environment."

}

variable "override_json_string" {
  type        = string
  default     = null
  description = "Override default values with a JSON object. Any JSON other than an empty string overrides other configuration changes."
}

##############################################################################
# Dedicatedhost Variables
##############################################################################

variable "enable_dedicated_host" {
  type        = bool
  default     = false
  description = "Set this option to true to enable dedicated hosts for the VSI created for workload servers. The default value is false. When a dedicated host is enabled, the solution supports only static worker nodes with a single profile, and multiple profile combinations are not supported. For example, you can select a profile from a single family, such as bx2, cx2, or mx2. If you are provisioning a static cluster with a third-generation profile, ensure that dedicated hosts are supported in the chosen regions, as not all regions support dedicated hosts for third-gen profiles. To learn more about dedicated host, [click here.](https://cloud.ibm.com/docs/vpc?topic=vpc-dh-profiles&interface=ui)"
  validation {
    condition     = !(var.enable_dedicated_host && length(var.static_compute_instances) != 1)
    error_message = "When 'enable_dedicated_host' is true, only one profile should be specified in 'static_compute_instances'."
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
