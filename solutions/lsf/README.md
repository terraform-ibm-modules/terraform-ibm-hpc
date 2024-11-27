## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_ansible"></a> [ansible](#requirement\_ansible) | ~> 1.3.0 |
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | >= 1.68.1, < 2.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_ibm"></a> [ibm](#provider\_ibm) | 1.70.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_lsf"></a> [lsf](#module\_lsf) | ./../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [ibm_is_vpc.itself](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_cidr"></a> [allowed\_cidr](#input\_allowed\_cidr) | Network CIDR to access the VPC. This is used to manage network ACL rules for accessing the cluster. | `list(string)` | n/a | yes |
| <a name="input_bastion_ssh_keys"></a> [bastion\_ssh\_keys](#input\_bastion\_ssh\_keys) | The key pair to use to access the bastion host. | `list(string)` | `null` | no |
| <a name="input_bastion_subnets_cidr"></a> [bastion\_subnets\_cidr](#input\_bastion\_subnets\_cidr) | Subnet CIDR block to launch the bastion host. | `list(string)` | <pre>[<br>  "10.0.0.0/24"<br>]</pre> | no |
| <a name="input_client_instances"></a> [client\_instances](#input\_client\_instances) | Number of instances to be launched for client. | <pre>list(<br>    object({<br>      profile = string<br>      count   = number<br>      image   = string<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "count": 2,<br>    "image": "ibm-redhat-8-10-minimal-amd64-2",<br>    "profile": "cx2-2x4"<br>  }<br>]</pre> | no |
| <a name="input_client_ssh_keys"></a> [client\_ssh\_keys](#input\_client\_ssh\_keys) | The key pair to use to launch the client host. | `list(string)` | `null` | no |
| <a name="input_client_subnets_cidr"></a> [client\_subnets\_cidr](#input\_client\_subnets\_cidr) | Subnet CIDR block to launch the client host. | `list(string)` | <pre>[<br>  "10.10.10.0/24",<br>  "10.20.10.0/24",<br>  "10.30.10.0/24"<br>]</pre> | no |
| <a name="input_compute_gui_password"></a> [compute\_gui\_password](#input\_compute\_gui\_password) | Password for compute cluster GUI | `string` | `"hpc@IBMCloud"` | no |
| <a name="input_compute_gui_username"></a> [compute\_gui\_username](#input\_compute\_gui\_username) | GUI user to perform system management and monitoring tasks on compute cluster. | `string` | `"admin"` | no |
| <a name="input_compute_ssh_keys"></a> [compute\_ssh\_keys](#input\_compute\_ssh\_keys) | The key pair to use to launch the compute host. | `list(string)` | `null` | no |
| <a name="input_compute_subnets_cidr"></a> [compute\_subnets\_cidr](#input\_compute\_subnets\_cidr) | Subnet CIDR block to launch the compute cluster host. | `list(string)` | <pre>[<br>  "10.10.20.0/24",<br>  "10.20.20.0/24",<br>  "10.30.20.0/24"<br>]</pre> | no |
| <a name="input_cos_instance_name"></a> [cos\_instance\_name](#input\_cos\_instance\_name) | Exiting COS instance name | `string` | `null` | no |
| <a name="input_deployer_instance_profile"></a> [deployer\_instance\_profile](#input\_deployer\_instance\_profile) | Deployer should be only used for better deployment performance | `string` | `"mx2-4x32"` | no |
| <a name="input_dns_custom_resolver_id"></a> [dns\_custom\_resolver\_id](#input\_dns\_custom\_resolver\_id) | IBM Cloud DNS custom resolver id. | `string` | `null` | no |
| <a name="input_dns_domain_names"></a> [dns\_domain\_names](#input\_dns\_domain\_names) | IBM Cloud HPC DNS domain names. | <pre>object({<br>    compute  = string<br>    storage  = string<br>    protocol = string<br>  })</pre> | <pre>{<br>  "compute": "comp.com",<br>  "protocol": "ces.com",<br>  "storage": "strg.com"<br>}</pre> | no |
| <a name="input_dns_instance_id"></a> [dns\_instance\_id](#input\_dns\_instance\_id) | IBM Cloud HPC DNS service instance id. | `string` | `null` | no |
| <a name="input_dynamic_compute_instances"></a> [dynamic\_compute\_instances](#input\_dynamic\_compute\_instances) | MaxNumber of instances to be launched for compute cluster. | <pre>list(<br>    object({<br>      profile = string<br>      count   = number<br>      image   = string<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "count": 1024,<br>    "image": "ibm-redhat-8-10-minimal-amd64-2",<br>    "profile": "cx2-2x4"<br>  }<br>]</pre> | no |
| <a name="input_enable_atracker"></a> [enable\_atracker](#input\_enable\_atracker) | Enable Activity tracker | `bool` | `true` | no |
| <a name="input_enable_bastion"></a> [enable\_bastion](#input\_enable\_bastion) | The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN or direct connection, set this value to false. | `bool` | `true` | no |
| <a name="input_enable_cos_integration"></a> [enable\_cos\_integration](#input\_enable\_cos\_integration) | Integrate COS with HPC solution | `bool` | `true` | no |
| <a name="input_enable_deployer"></a> [enable\_deployer](#input\_enable\_deployer) | Deployer should be only used for better deployment performance | `bool` | `false` | no |
| <a name="input_enable_vpc_flow_logs"></a> [enable\_vpc\_flow\_logs](#input\_enable\_vpc\_flow\_logs) | Enable Activity tracker | `bool` | `true` | no |
| <a name="input_enable_vpn"></a> [enable\_vpn](#input\_enable\_vpn) | The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN, set this value to true. | `bool` | `false` | no |
| <a name="input_file_shares"></a> [file\_shares](#input\_file\_shares) | Custom file shares to access shared storage | <pre>list(<br>    object({<br>      mount_path = string,<br>      size       = number,<br>      iops       = number<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "iops": 1000,<br>    "mount_path": "/mnt/binaries",<br>    "size": 100<br>  },<br>  {<br>    "iops": 1000,<br>    "mount_path": "/mnt/data",<br>    "size": 100<br>  }<br>]</pre> | no |
| <a name="input_hpcs_instance_name"></a> [hpcs\_instance\_name](#input\_hpcs\_instance\_name) | Hyper Protect Crypto Service instance | `string` | `null` | no |
| <a name="input_ibm_customer_number"></a> [ibm\_customer\_number](#input\_ibm\_customer\_number) | Comma-separated list of the IBM Customer Number(s) (ICN) that is used for the Bring Your Own License (BYOL) entitlement check. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn). | `string` | n/a | yes |
| <a name="input_ibmcloud_api_key"></a> [ibmcloud\_api\_key](#input\_ibmcloud\_api\_key) | IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required. | `string` | n/a | yes |
| <a name="input_key_management"></a> [key\_management](#input\_key\_management) | null/key\_protect/hs\_crypto | `string` | `"key_protect"` | no |
| <a name="input_management_instances"></a> [management\_instances](#input\_management\_instances) | Number of instances to be launched for management. | <pre>list(<br>    object({<br>      profile = string<br>      count   = number<br>      image   = string<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "count": 2,<br>    "image": "ibm-redhat-8-10-minimal-amd64-2",<br>    "profile": "cx2-2x4"<br>  }<br>]</pre> | no |
| <a name="input_network_cidr"></a> [network\_cidr](#input\_network\_cidr) | Network CIDR for the VPC. This is used to manage network ACL rules for cluster provisioning. | `string` | `"10.0.0.0/8"` | no |
| <a name="input_nsd_details"></a> [nsd\_details](#input\_nsd\_details) | Storage scale NSD details | <pre>list(<br>    object({<br>      profile  = string<br>      capacity = optional(number)<br>      iops     = optional(number)<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "capacity": 100,<br>    "iops": 1000,<br>    "profile": "custom"<br>  }<br>]</pre> | no |
| <a name="input_override"></a> [override](#input\_override) | Override default values with custom JSON template. This uses the file `override.json` to allow users to create a fully customized environment. | `bool` | `false` | no |
| <a name="input_override_json_string"></a> [override\_json\_string](#input\_override\_json\_string) | Override default values with a JSON object. Any JSON other than an empty string overrides other configuration changes. | `string` | `null` | no |
| <a name="input_placement_strategy"></a> [placement\_strategy](#input\_placement\_strategy) | VPC placement groups to create (null / host\_spread / power\_spread) | `string` | `null` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters. | `string` | `"lsf"` | no |
| <a name="input_protocol_instances"></a> [protocol\_instances](#input\_protocol\_instances) | Number of instances to be launched for protocol hosts. | <pre>list(<br>    object({<br>      profile = string<br>      count   = number<br>      image   = string<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "count": 2,<br>    "image": "ibm-redhat-8-10-minimal-amd64-2",<br>    "profile": "bx2-2x8"<br>  }<br>]</pre> | no |
| <a name="input_protocol_subnets_cidr"></a> [protocol\_subnets\_cidr](#input\_protocol\_subnets\_cidr) | Subnet CIDR block to launch the storage cluster host. | `list(string)` | <pre>[<br>  "10.10.40.0/24",<br>  "10.20.40.0/24",<br>  "10.30.40.0/24"<br>]</pre> | no |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | String describing resource groups to create or reference | `string` | `"Default"` | no |
| <a name="input_ssh_keys"></a> [ssh\_keys](#input\_ssh\_keys) | The key pair to use to access the HPC cluster. | `list(string)` | `null` | no |
| <a name="input_static_compute_instances"></a> [static\_compute\_instances](#input\_static\_compute\_instances) | Min Number of instances to be launched for compute cluster. | <pre>list(<br>    object({<br>      profile = string<br>      count   = number<br>      image   = string<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "count": 1,<br>    "image": "ibm-redhat-8-10-minimal-amd64-2",<br>    "profile": "cx2-2x4"<br>  }<br>]</pre> | no |
| <a name="input_storage_gui_password"></a> [storage\_gui\_password](#input\_storage\_gui\_password) | Password for storage cluster GUI | `string` | `"hpc@IBMCloud"` | no |
| <a name="input_storage_gui_username"></a> [storage\_gui\_username](#input\_storage\_gui\_username) | GUI user to perform system management and monitoring tasks on storage cluster. | `string` | `"admin"` | no |
| <a name="input_storage_instances"></a> [storage\_instances](#input\_storage\_instances) | Number of instances to be launched for storage cluster. | <pre>list(<br>    object({<br>      profile         = string<br>      count           = number<br>      image           = string<br>      filesystem_name = optional(string)<br>    })<br>  )</pre> | <pre>[<br>  {<br>    "count": 2,<br>    "filesystem_name": "fs1",<br>    "image": "ibm-redhat-8-10-minimal-amd64-2",<br>    "profile": "bx2-2x8"<br>  }<br>]</pre> | no |
| <a name="input_storage_ssh_keys"></a> [storage\_ssh\_keys](#input\_storage\_ssh\_keys) | The key pair to use to launch the storage cluster host. | `list(string)` | `null` | no |
| <a name="input_storage_subnets_cidr"></a> [storage\_subnets\_cidr](#input\_storage\_subnets\_cidr) | Subnet CIDR block to launch the storage cluster host. | `list(string)` | <pre>[<br>  "10.10.30.0/24",<br>  "10.20.30.0/24",<br>  "10.30.30.0/24"<br>]</pre> | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc) | `string` | `null` | no |
| <a name="input_vpn_peer_address"></a> [vpn\_peer\_address](#input\_vpn\_peer\_address) | The peer public IP address to which the VPN will be connected. | `string` | `null` | no |
| <a name="input_vpn_peer_cidr"></a> [vpn\_peer\_cidr](#input\_vpn\_peer\_cidr) | The peer CIDRs (e.g., 192.168.0.0/24) to which the VPN will be connected. | `list(string)` | `null` | no |
| <a name="input_vpn_preshared_key"></a> [vpn\_preshared\_key](#input\_vpn\_preshared\_key) | The pre-shared key for the VPN. | `string` | `null` | no |
| <a name="input_zones"></a> [zones](#input\_zones) | Region where VPC will be created. To find your VPC region, use `ibmcloud is regions` command to find available regions. | `list(string)` | n/a | yes |

## Outputs

No outputs.
