## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0, <1.6.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_hpc"></a> [hpc](#module\_hpc) | ./solutions/hpc | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_cidr"></a> [allowed\_cidr](#input\_allowed\_cidr) | Network CIDR to access the VPC. This is used to manage network ACL rules for accessing the cluster. | `list(string)` | <pre>[<br>  "10.0.0.0/8"<br>]</pre> | no |
| <a name="input_bastion_ssh_keys"></a> [bastion\_ssh\_keys](#input\_bastion\_ssh\_keys) | The key pair to use to access the bastion host. | `list(string)` | n/a | yes |
| <a name="input_bastion_subnets_cidr"></a> [bastion\_subnets\_cidr](#input\_bastion\_subnets\_cidr) | Subnet CIDR block to launch the bastion host. | `list(string)` | <pre>[<br>  "10.0.0.0/24"<br>]</pre> | no |
| <a name="input_boot_volume_encryption_enabled"></a> [boot\_volume\_encryption\_enabled](#input\_boot\_volume\_encryption\_enabled) | Set to true when key management is set | `bool` | `true` | no |
| <a name="input_bootstrap_instance_profile"></a> [bootstrap\_instance\_profile](#input\_bootstrap\_instance\_profile) | Bootstrap should be only used for better deployment performance | `string` | `"mx2-4x32"` | no |
| <a name="input_compute_gui_password"></a> [compute\_gui\_password](#input\_compute\_gui\_password) | Password for compute cluster GUI | `string` | n/a | yes |
| <a name="input_compute_gui_username"></a> [compute\_gui\_username](#input\_compute\_gui\_username) | GUI user to perform system management and monitoring tasks on compute cluster. | `string` | `"admin"` | no |
| <a name="input_compute_image_name"></a> [compute\_image\_name](#input\_compute\_image\_name) | Image name to use for provisioning the compute cluster instances. | `string` | `"ibm-redhat-8-6-minimal-amd64-5"` | no |
| <a name="input_compute_ssh_keys"></a> [compute\_ssh\_keys](#input\_compute\_ssh\_keys) | The key pair to use to launch the compute host. | `list(string)` | n/a | yes |
| <a name="input_compute_subnets_cidr"></a> [compute\_subnets\_cidr](#input\_compute\_subnets\_cidr) | Subnet CIDR block to launch the compute cluster host. | `list(string)` | <pre>[<br>  "10.10.20.0/24",<br>  "10.20.20.0/24",<br>  "10.30.20.0/24"<br>]</pre> | no |
| <a name="input_cos_instance_name"></a> [cos\_instance\_name](#input\_cos\_instance\_name) | Exiting COS instance name | `string` | `null` | no |
| <a name="input_dns_custom_resolver_id"></a> [dns\_custom\_resolver\_id](#input\_dns\_custom\_resolver\_id) | IBM Cloud DNS custom resolver id. | `string` | `null` | no |
| <a name="input_dns_domain_names"></a> [dns\_domain\_names](#input\_dns\_domain\_names) | IBM Cloud HPC DNS domain names. | <pre>object({<br>    compute  = string<br>    storage  = string<br>    protocol = string<br>  })</pre> | <pre>{<br>  "compute": "comp.com",<br>  "protocol": "ces.com",<br>  "storage": "strg.com"<br>}</pre> | no |
| <a name="input_dns_instance_id"></a> [dns\_instance\_id](#input\_dns\_instance\_id) | IBM Cloud HPC DNS service instance id. | `string` | `null` | no |
| <a name="input_dynamic_compute_instances"></a> [dynamic\_compute\_instances](#input\_dynamic\_compute\_instances) | MaxNumber of instances to be launched for compute cluster. | <pre>list(<br>    object({<br>      profile = string<br>      count   = number<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "count": 250,<br>    "profile": "cx2-2x4"<br>  }<br>]</pre> | no |
| <a name="input_enable_atracker"></a> [enable\_atracker](#input\_enable\_atracker) | Enable Activity tracker | `bool` | `true` | no |
| <a name="input_enable_bastion"></a> [enable\_bastion](#input\_enable\_bastion) | The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN or direct connection, set this value to false. | `bool` | `true` | no |
| <a name="input_enable_bootstrap"></a> [enable\_bootstrap](#input\_enable\_bootstrap) | Bootstrap should be only used for better deployment performance | `bool` | `false` | no |
| <a name="input_enable_cos_integration"></a> [enable\_cos\_integration](#input\_enable\_cos\_integration) | Integrate COS with HPC solution | `bool` | `true` | no |
| <a name="input_enable_vpc_flow_logs"></a> [enable\_vpc\_flow\_logs](#input\_enable\_vpc\_flow\_logs) | Enable Activity tracker | `bool` | `true` | no |
| <a name="input_enable_vpn"></a> [enable\_vpn](#input\_enable\_vpn) | The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN, set this value to true. | `bool` | `false` | no |
| <a name="input_file_shares"></a> [file\_shares](#input\_file\_shares) | Custom file shares to access shared storage | <pre>list(<br>    object({<br>      mount_path = string,<br>      size       = number,<br>      iops       = number<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "iops": 1000,<br>    "mount_path": "/mnt/binaries",<br>    "size": 100<br>  },<br>  {<br>    "iops": 1000,<br>    "mount_path": "/mnt/data",<br>    "size": 100<br>  }<br>]</pre> | no |
| <a name="input_hpcs_instance_name"></a> [hpcs\_instance\_name](#input\_hpcs\_instance\_name) | Hyper Protect Crypto Service instance | `string` | `null` | no |
| <a name="input_ibm_customer_number"></a> [ibm\_customer\_number](#input\_ibm\_customer\_number) | Comma-separated list of the IBM Customer Number(s) (ICN) that is used for the Bring Your Own License (BYOL) entitlement check. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn). | `string` | `""` | no |
| <a name="input_ibmcloud_api_key"></a> [ibmcloud\_api\_key](#input\_ibmcloud\_api\_key) | IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required. | `string` | `null` | no |
| <a name="input_key_management"></a> [key\_management](#input\_key\_management) | null/key\_protect/hs\_crypto | `string` | `"key_protect"` | no |
| <a name="input_login_image_name"></a> [login\_image\_name](#input\_login\_image\_name) | Image name to use for provisioning the login instances. | `string` | `"ibm-redhat-8-6-minimal-amd64-5"` | no |
| <a name="input_login_instances"></a> [login\_instances](#input\_login\_instances) | Number of instances to be launched for login. | <pre>list(<br>    object({<br>      profile = string<br>      count   = number<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "count": 1,<br>    "profile": "cx2-2x4"<br>  }<br>]</pre> | no |
| <a name="input_login_ssh_keys"></a> [login\_ssh\_keys](#input\_login\_ssh\_keys) | The key pair to use to launch the login host. | `list(string)` | n/a | yes |
| <a name="input_login_subnets_cidr"></a> [login\_subnets\_cidr](#input\_login\_subnets\_cidr) | Subnet CIDR block to launch the login host. | `list(string)` | <pre>[<br>  "10.10.10.0/24",<br>  "10.20.10.0/24",<br>  "10.30.10.0/24"<br>]</pre> | no |
| <a name="input_management_image_name"></a> [management\_image\_name](#input\_management\_image\_name) | Image name to use for provisioning the management cluster instances. | `string` | `"ibm-redhat-8-6-minimal-amd64-5"` | no |
| <a name="input_management_instances"></a> [management\_instances](#input\_management\_instances) | Number of instances to be launched for management. | <pre>list(<br>    object({<br>      profile = string<br>      count   = number<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "count": 3,<br>    "profile": "cx2-2x4"<br>  }<br>]</pre> | no |
| <a name="input_network_cidr"></a> [network\_cidr](#input\_network\_cidr) | Network CIDR for the VPC. This is used to manage network ACL rules for cluster provisioning. | `string` | `"10.0.0.0/8"` | no |
| <a name="input_nsd_details"></a> [nsd\_details](#input\_nsd\_details) | Storage scale NSD details | <pre>list(<br>    object({<br>      profile  = string<br>      capacity = optional(number)<br>      iops     = optional(number)<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "iops": 100,<br>    "profile": "custom",<br>    "size": 100<br>  }<br>]</pre> | no |
| <a name="input_placement_strategy"></a> [placement\_strategy](#input\_placement\_strategy) | VPC placement groups to create (null / host\_spread / power\_spread) | `string` | `null` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters. | `string` | n/a | yes |
| <a name="input_protocol_instances"></a> [protocol\_instances](#input\_protocol\_instances) | Number of instances to be launched for protocol hosts. | <pre>list(<br>    object({<br>      profile = string<br>      count   = number<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "count": 2,<br>    "profile": "bx2-2x8"<br>  }<br>]</pre> | no |
| <a name="input_protocol_subnets_cidr"></a> [protocol\_subnets\_cidr](#input\_protocol\_subnets\_cidr) | Subnet CIDR block to launch the storage cluster host. | `list(string)` | <pre>[<br>  "10.10.40.0/24",<br>  "10.20.40.0/24",<br>  "10.30.40.0/24"<br>]</pre> | no |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | String describing resource groups to create or reference | `string` | `null` | no |
| <a name="input_scheduler"></a> [scheduler](#input\_scheduler) | Select one of the scheduler (LSF/Symphony/Slurm/None) | `string` | `"LSF"` | no |
| <a name="input_static_compute_instances"></a> [static\_compute\_instances](#input\_static\_compute\_instances) | Min Number of instances to be launched for compute cluster. | <pre>list(<br>    object({<br>      profile = string<br>      count   = number<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "count": 0,<br>    "profile": "cx2-2x4"<br>  }<br>]</pre> | no |
| <a name="input_storage_gui_password"></a> [storage\_gui\_password](#input\_storage\_gui\_password) | Password for storage cluster GUI | `string` | n/a | yes |
| <a name="input_storage_gui_username"></a> [storage\_gui\_username](#input\_storage\_gui\_username) | GUI user to perform system management and monitoring tasks on storage cluster. | `string` | `"admin"` | no |
| <a name="input_storage_image_name"></a> [storage\_image\_name](#input\_storage\_image\_name) | Image name to use for provisioning the storage cluster instances. | `string` | `"ibm-redhat-8-6-minimal-amd64-5"` | no |
| <a name="input_storage_instances"></a> [storage\_instances](#input\_storage\_instances) | Number of instances to be launched for storage cluster. | <pre>list(<br>    object({<br>      profile = string<br>      count   = number<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "count": 3,<br>    "profile": "bx2-2x8"<br>  }<br>]</pre> | no |
| <a name="input_storage_ssh_keys"></a> [storage\_ssh\_keys](#input\_storage\_ssh\_keys) | The key pair to use to launch the storage cluster host. | `list(string)` | n/a | yes |
| <a name="input_storage_subnets_cidr"></a> [storage\_subnets\_cidr](#input\_storage\_subnets\_cidr) | Subnet CIDR block to launch the storage cluster host. | `list(string)` | <pre>[<br>  "10.10.30.0/24",<br>  "10.20.30.0/24",<br>  "10.30.30.0/24"<br>]</pre> | no |
| <a name="input_storage_type"></a> [storage\_type](#input\_storage\_type) | Select the required storage type(scratch/persistent/eval). | `string` | `"scratch"` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc) | `string` | `null` | no |
| <a name="input_vpn_peer_address"></a> [vpn\_peer\_address](#input\_vpn\_peer\_address) | The peer public IP address to which the VPN will be connected. | `string` | `null` | no |
| <a name="input_vpn_peer_cidr"></a> [vpn\_peer\_cidr](#input\_vpn\_peer\_cidr) | The peer CIDRs (e.g., 192.168.0.0/24) to which the VPN will be connected. | `list(string)` | `null` | no |
| <a name="input_vpn_preshared_key"></a> [vpn\_preshared\_key](#input\_vpn\_preshared\_key) | The pre-shared key for the VPN. | `string` | `null` | no |
| <a name="input_zones"></a> [zones](#input\_zones) | Region where VPC will be created. To find your VPC region, use `ibmcloud is regions` command to find available regions. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ssh_command"></a> [ssh\_command](#output\_ssh\_command) | SSH command to connect to HPC cluster |
