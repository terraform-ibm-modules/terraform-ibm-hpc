## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | >= 1.68.1, < 2.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_lsf"></a> [lsf](#module\_lsf) | ./../.. | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_cidr"></a> [allowed\_cidr](#input\_allowed\_cidr) | Network CIDR to access the VPC. This is used to manage network ACL rules for accessing the cluster. | `list(string)` | n/a | yes |
| <a name="input_bastion_image"></a> [bastion\_image](#input\_bastion\_image) | The image to use to deploy the bastion host. | `string` | `"ibm-ubuntu-22-04-3-minimal-amd64-1"` | no |
| <a name="input_bastion_instance_profile"></a> [bastion\_instance\_profile](#input\_bastion\_instance\_profile) | Deployer should be only used for better deployment performance | `string` | `"cx2-4x8"` | no |
| <a name="input_bastion_ssh_keys"></a> [bastion\_ssh\_keys](#input\_bastion\_ssh\_keys) | The key pair to use to access the bastion host. | `list(string)` | `null` | no |
| <a name="input_bastion_subnets_cidr"></a> [bastion\_subnets\_cidr](#input\_bastion\_subnets\_cidr) | Subnet CIDR block to launch the bastion host. | `string` | `"10.0.0.0/24"` | no |
| <a name="input_client_instances"></a> [client\_instances](#input\_client\_instances) | Number of instances to be launched for client. | <pre>list(<br>    object({<br>      profile = string<br>      count   = number<br>      image   = string<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "count": 2,<br>    "image": "ibm-redhat-8-10-minimal-amd64-2",<br>    "profile": "cx2-2x4"<br>  }<br>]</pre> | no |
| <a name="input_client_ssh_keys"></a> [client\_ssh\_keys](#input\_client\_ssh\_keys) | The key pair to use to launch the client host. | `list(string)` | `null` | no |
| <a name="input_client_subnets_cidr"></a> [client\_subnets\_cidr](#input\_client\_subnets\_cidr) | Subnet CIDR block to launch the client host. | `string` | `"10.10.10.0/24"` | no |
| <a name="input_compute_gui_password"></a> [compute\_gui\_password](#input\_compute\_gui\_password) | Password for compute cluster GUI | `string` | `"hpc@IBMCloud"` | no |
| <a name="input_compute_gui_username"></a> [compute\_gui\_username](#input\_compute\_gui\_username) | GUI user to perform system management and monitoring tasks on compute cluster. | `string` | `"admin"` | no |
| <a name="input_compute_ssh_keys"></a> [compute\_ssh\_keys](#input\_compute\_ssh\_keys) | The key pair to use to launch the compute host. | `list(string)` | `null` | no |
| <a name="input_compute_subnets_cidr"></a> [compute\_subnets\_cidr](#input\_compute\_subnets\_cidr) | Subnet CIDR block to launch the compute cluster host. | `string` | `"10.10.20.0/24"` | no |
| <a name="input_cos_instance_name"></a> [cos\_instance\_name](#input\_cos\_instance\_name) | Exiting COS instance name | `string` | `null` | no |
| <a name="input_deployer_image"></a> [deployer\_image](#input\_deployer\_image) | The image to use to deploy the deployer host. | `string` | `"jay-lsf-new-image"` | no |
| <a name="input_deployer_instance_profile"></a> [deployer\_instance\_profile](#input\_deployer\_instance\_profile) | Deployer should be only used for better deployment performance | `string` | `"bx2-8x32"` | no |
| <a name="input_dns_custom_resolver_id"></a> [dns\_custom\_resolver\_id](#input\_dns\_custom\_resolver\_id) | IBM Cloud DNS custom resolver id. | `string` | `null` | no |
| <a name="input_dns_domain_names"></a> [dns\_domain\_names](#input\_dns\_domain\_names) | IBM Cloud HPC DNS domain names. | <pre>object({<br>    compute  = string<br>    storage  = string<br>    protocol = string<br>  })</pre> | <pre>{<br>  "compute": "comp.com",<br>  "protocol": "ces.com",<br>  "storage": "strg.com"<br>}</pre> | no |
| <a name="input_dns_instance_id"></a> [dns\_instance\_id](#input\_dns\_instance\_id) | IBM Cloud HPC DNS service instance id. | `string` | `null` | no |
| <a name="input_dynamic_compute_instances"></a> [dynamic\_compute\_instances](#input\_dynamic\_compute\_instances) | MaxNumber of instances to be launched for compute cluster. | <pre>list(<br>    object({<br>      profile = string<br>      count   = number<br>      image   = string<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "count": 1024,<br>    "image": "ibm-redhat-8-10-minimal-amd64-2",<br>    "profile": "cx2-2x4"<br>  }<br>]</pre> | no |
| <a name="input_enable_bastion"></a> [enable\_bastion](#input\_enable\_bastion) | The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN or direct connection, set this value to false. | `bool` | `true` | no |
| <a name="input_enable_cos_integration"></a> [enable\_cos\_integration](#input\_enable\_cos\_integration) | Integrate COS with HPC solution | `bool` | `true` | no |
| <a name="input_enable_deployer"></a> [enable\_deployer](#input\_enable\_deployer) | Deployer should be only used for better deployment performance | `bool` | `false` | no |
| <a name="input_enable_hyperthreading"></a> [enable\_hyperthreading](#input\_enable\_hyperthreading) | Setting this to true will enable hyper-threading in the worker nodes of the cluster (default). Otherwise, hyper-threading will be disabled. | `bool` | `true` | no |
| <a name="input_enable_vpc_flow_logs"></a> [enable\_vpc\_flow\_logs](#input\_enable\_vpc\_flow\_logs) | Enable Activity tracker | `bool` | `true` | no |
| <a name="input_enable_vpn"></a> [enable\_vpn](#input\_enable\_vpn) | The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN, set this value to true. | `bool` | `false` | no |
| <a name="input_existing_resource_group"></a> [existing\_resource\_group](#input\_existing\_resource\_group) | String describing resource groups to create or reference | `string` | `"Default"` | no |
| <a name="input_file_shares"></a> [file\_shares](#input\_file\_shares) | Custom file shares to access shared storage | <pre>list(<br>    object({<br>      mount_path = string,<br>      size       = number,<br>      iops       = number<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "iops": 1000,<br>    "mount_path": "/mnt/binaries",<br>    "size": 100<br>  },<br>  {<br>    "iops": 1000,<br>    "mount_path": "/mnt/data",<br>    "size": 100<br>  }<br>]</pre> | no |
| <a name="input_hpcs_instance_name"></a> [hpcs\_instance\_name](#input\_hpcs\_instance\_name) | Hyper Protect Crypto Service instance | `string` | `null` | no |
| <a name="input_ibm_customer_number"></a> [ibm\_customer\_number](#input\_ibm\_customer\_number) | Comma-separated list of the IBM Customer Number(s) (ICN) that is used for the Bring Your Own License (BYOL) entitlement check. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn). | `string` | n/a | yes |
| <a name="input_ibmcloud_api_key"></a> [ibmcloud\_api\_key](#input\_ibmcloud\_api\_key) | IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required. | `string` | n/a | yes |
| <a name="input_key_management"></a> [key\_management](#input\_key\_management) | Set the value as key\_protect to enable customer managed encryption for boot volume and file share. If the key\_management is set as null, IBM Cloud resources will be always be encrypted through provider managed. | `string` | `"key_protect"` | no |
| <a name="input_kms_instance_name"></a> [kms\_instance\_name](#input\_kms\_instance\_name) | Provide the name of the existing Key Protect instance associated with the Key Management Service. Note: To use existing kms\_instance\_name set key\_management as key\_protect. The name can be found under the details of the KMS, see [View key-protect ID](https://cloud.ibm.com/docs/key-protect?topic=key-protect-retrieve-instance-ID&interface=ui). | `string` | `null` | no |
| <a name="input_kms_key_name"></a> [kms\_key\_name](#input\_kms\_key\_name) | Provide the existing kms key name that you want to use for the IBM Cloud HPC cluster. Note: kms\_key\_name to be considered only if key\_management value is set as key\_protect.(for example kms\_key\_name: my-encryption-key). | `string` | `null` | no |
| <a name="input_management_instances"></a> [management\_instances](#input\_management\_instances) | Number of instances to be launched for management. | <pre>list(<br>    object({<br>      profile = string<br>      count   = number<br>      image   = string<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "count": 2,<br>    "image": "ibm-redhat-8-10-minimal-amd64-2",<br>    "profile": "cx2-2x4"<br>  }<br>]</pre> | no |
| <a name="input_network_cidr"></a> [network\_cidr](#input\_network\_cidr) | Network CIDR for the VPC. This is used to manage network ACL rules for cluster provisioning. | `string` | `"10.0.0.0/8"` | no |
| <a name="input_observability_atracker_enable"></a> [observability\_atracker\_enable](#input\_observability\_atracker\_enable) | Activity Tracker Event Routing to configure how to route auditing events. While multiple Activity Tracker instances can be created, only one tracker is needed to capture all events. Creating additional trackers is unnecessary if an existing Activity Tracker is already integrated with a COS bucket. In such cases, set the value to false, as all events can be monitored and accessed through the existing Activity Tracker. | `bool` | `true` | no |
| <a name="input_observability_atracker_target_type"></a> [observability\_atracker\_target\_type](#input\_observability\_atracker\_target\_type) | All the events will be stored in either COS bucket or Cloud Logs on the basis of user input, so customers can retrieve or ingest them in their system. | `string` | `"cloudlogs"` | no |
| <a name="input_observability_enable_metrics_routing"></a> [observability\_enable\_metrics\_routing](#input\_observability\_enable\_metrics\_routing) | Enable metrics routing to manage metrics at the account-level by configuring targets and routes that define where data points are routed. | `bool` | `false` | no |
| <a name="input_observability_enable_platform_logs"></a> [observability\_enable\_platform\_logs](#input\_observability\_enable\_platform\_logs) | Setting this to true will create a tenant in the same region that the Cloud Logs instance is provisioned to enable platform logs for that region. NOTE: You can only have 1 tenant per region in an account. | `bool` | `false` | no |
| <a name="input_observability_logs_enable_for_compute"></a> [observability\_logs\_enable\_for\_compute](#input\_observability\_logs\_enable\_for\_compute) | Set false to disable IBM Cloud Logs integration. If enabled, infrastructure and LSF application logs from Compute Nodes will be ingested. | `bool` | `false` | no |
| <a name="input_observability_logs_enable_for_management"></a> [observability\_logs\_enable\_for\_management](#input\_observability\_logs\_enable\_for\_management) | Set false to disable IBM Cloud Logs integration. If enabled, infrastructure and LSF application logs from Management Nodes will be ingested. | `bool` | `false` | no |
| <a name="input_observability_logs_retention_period"></a> [observability\_logs\_retention\_period](#input\_observability\_logs\_retention\_period) | The number of days IBM Cloud Logs will retain the logs data in Priority insights. Allowed values: 7, 14, 30, 60, 90. | `number` | `7` | no |
| <a name="input_observability_monitoring_enable"></a> [observability\_monitoring\_enable](#input\_observability\_monitoring\_enable) | Set false to disable IBM Cloud Monitoring integration. If enabled, infrastructure and LSF application metrics from Management Nodes will be ingested. | `bool` | `true` | no |
| <a name="input_observability_monitoring_on_compute_nodes_enable"></a> [observability\_monitoring\_on\_compute\_nodes\_enable](#input\_observability\_monitoring\_on\_compute\_nodes\_enable) | Set false to disable IBM Cloud Monitoring integration. If enabled, infrastructure metrics from Compute Nodes will be ingested. | `bool` | `false` | no |
| <a name="input_observability_monitoring_plan"></a> [observability\_monitoring\_plan](#input\_observability\_monitoring\_plan) | Type of service plan for IBM Cloud Monitoring instance. You can choose one of the following: lite, graduated-tier. For all details visit [IBM Cloud Monitoring Service Plans](https://cloud.ibm.com/docs/monitoring?topic=monitoring-service_plans). | `string` | `"graduated-tier"` | no |
| <a name="input_override"></a> [override](#input\_override) | Override default values with custom JSON template. This uses the file `override.json` to allow users to create a fully customized environment. | `bool` | `false` | no |
| <a name="input_override_json_string"></a> [override\_json\_string](#input\_override\_json\_string) | Override default values with a JSON object. Any JSON other than an empty string overrides other configuration changes. | `string` | `null` | no |
| <a name="input_placement_strategy"></a> [placement\_strategy](#input\_placement\_strategy) | VPC placement groups to create (null / host\_spread / power\_spread) | `string` | `null` | no |
| <a name="input_prefix"></a> [cluster_prefix](#input\_prefix) | A unique identifier for resources. Must begin with a letter and end with a letter or number. This cluster_prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters. | `string` | `"lsf"` | no |
| <a name="input_protocol_instances"></a> [protocol\_instances](#input\_protocol\_instances) | Number of instances to be launched for protocol hosts. | <pre>list(<br>    object({<br>      profile = string<br>      count   = number<br>      image   = string<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "count": 2,<br>    "image": "ibm-redhat-8-10-minimal-amd64-2",<br>    "profile": "bx2-2x8"<br>  }<br>]</pre> | no |
| <a name="input_protocol_subnets_cidr"></a> [protocol\_subnets\_cidr](#input\_protocol\_subnets\_cidr) | Subnet CIDR block to launch the storage cluster host. | `string` | `"10.10.40.0/24"` | no |
| <a name="input_scc_enable"></a> [scc\_enable](#input\_scc\_enable) | Flag to enable SCC instance creation. If true, an instance of SCC (Security and Compliance Center) will be created. | `bool` | `true` | no |
| <a name="input_scc_event_notification_plan"></a> [scc\_event\_notification\_plan](#input\_scc\_event\_notification\_plan) | Event Notifications Instance plan to be used (it's used with S.C.C. instance), possible values 'lite' and 'standard'. | `string` | `"lite"` | no |
| <a name="input_scc_location"></a> [scc\_location](#input\_scc\_location) | Location where the SCC instance is provisioned (possible choices 'us-south', 'eu-de', 'ca-tor', 'eu-es') | `string` | `"us-south"` | no |
| <a name="input_scc_profile"></a> [scc\_profile](#input\_scc\_profile) | Profile to be set on the SCC Instance (accepting empty, 'CIS IBM Cloud Foundations Benchmark' and 'IBM Cloud Framework for Financial Services') | `string` | `"CIS IBM Cloud Foundations Benchmark v1.1.0"` | no |
| <a name="input_skip_flowlogs_s2s_auth_policy"></a> [skip\_flowlogs\_s2s\_auth\_policy](#input\_skip\_flowlogs\_s2s\_auth\_policy) | Skip auth policy between flow logs service and COS instance, set to true if this policy is already in place on account. | `bool` | `false` | no |
| <a name="input_skip_iam_authorization_policy"></a> [skip\_iam\_authorization\_policy](#input\_skip\_iam\_authorization\_policy) | Set to false if authorization policy is required for VPC block storage volumes to access kms. This can be set to true if authorization policy already exists. For more information on how to create authorization policy manually, see [creating authorization policies for block storage volume](https://cloud.ibm.com/docs/vpc?topic=vpc-block-s2s-auth&interface=ui). | `bool` | `false` | no |
| <a name="input_skip_kms_s2s_auth_policy"></a> [skip\_kms\_s2s\_auth\_policy](#input\_skip\_kms\_s2s\_auth\_policy) | Skip auth policy between KMS service and COS instance, set to true if this policy is already in place on account. | `bool` | `false` | no |
| <a name="input_ssh_keys"></a> [ssh\_keys](#input\_ssh\_keys) | The key pair to use to access the HPC cluster. | `list(string)` | `null` | no |
| <a name="input_static_compute_instances"></a> [static\_compute\_instances](#input\_static\_compute\_instances) | Min Number of instances to be launched for compute cluster. | <pre>list(<br>    object({<br>      profile = string<br>      count   = number<br>      image   = string<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "count": 1,<br>    "image": "ibm-redhat-8-10-minimal-amd64-2",<br>    "profile": "cx2-2x4"<br>  }<br>]</pre> | no |
| <a name="input_storage_gui_password"></a> [storage\_gui\_password](#input\_storage\_gui\_password) | Password for storage cluster GUI | `string` | `"hpc@IBMCloud"` | no |
| <a name="input_storage_gui_username"></a> [storage\_gui\_username](#input\_storage\_gui\_username) | GUI user to perform system management and monitoring tasks on storage cluster. | `string` | `"admin"` | no |
| <a name="input_storage_instances"></a> [storage\_instances](#input\_storage\_instances) | Number of instances to be launched for storage cluster. | <pre>list(<br>    object({<br>      profile         = string<br>      count           = number<br>      image           = string<br>      filesystem_name = optional(string)<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "count": 2,<br>    "filesystem_name": "fs1",<br>    "image": "ibm-redhat-8-10-minimal-amd64-2",<br>    "profile": "bx2-2x8"<br>  }<br>]</pre> | no |
| <a name="input_storage_ssh_keys"></a> [storage\_ssh\_keys](#input\_storage\_ssh\_keys) | The key pair to use to launch the storage cluster host. | `list(string)` | `null` | no |
| <a name="input_storage_subnets_cidr"></a> [storage\_subnets\_cidr](#input\_storage\_subnets\_cidr) | Subnet CIDR block to launch the storage cluster host. | `string` | `"10.10.30.0/24"` | no |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc) | `string` | `null` | no |
| <a name="input_vpn_peer_address"></a> [vpn\_peer\_address](#input\_vpn\_peer\_address) | The peer public IP address to which the VPN will be connected. | `string` | `null` | no |
| <a name="input_vpn_peer_cidr"></a> [vpn\_peer\_cidr](#input\_vpn\_peer\_cidr) | The peer CIDRs (e.g., 192.168.0.0/24) to which the VPN will be connected. | `list(string)` | `null` | no |
| <a name="input_vpn_preshared_key"></a> [vpn\_preshared\_key](#input\_vpn\_preshared\_key) | The pre-shared key for the VPN. | `string` | `null` | no |
| <a name="input_zones"></a> [zones](#input\_zones) | Region where VPC will be created. To find your VPC region, use `ibmcloud is regions` command to find available regions. | `list(string)` | <pre>[<br>  "us-south-1",<br>  "us-south-2",<br>  "us-south-3"<br>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lsf"></a> [lsf](#output\_lsf) | LSF details |
