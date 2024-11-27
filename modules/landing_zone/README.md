## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_http"></a> [http](#requirement\_http) | 3.2.1 |
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | >= 1.53.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_landing-zone"></a> [landing-zone](#module\_landing-zone) | terraform-ibm-modules/landing-zone/ibm | 4.5.5 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_cidr"></a> [allowed\_cidr](#input\_allowed\_cidr) | Network CIDR to access the VPC. This is used to manage network ACL rules for accessing the cluster. | `list(string)` | <pre>[<br>  "10.0.0.0/8"<br>]</pre> | no |
| <a name="input_deployer_ssh_keys"></a> [deployer\_ssh\_keys](#input\_deployer\_ssh\_keys) | The key pair to use to access the deployer host. | `list(string)` | n/a | yes |
| <a name="input_compute_ssh_keys"></a> [compute\_ssh\_keys](#input\_compute\_ssh\_keys) | The key pair to use to launch the compute host. | `list(string)` | n/a | yes |
| <a name="input_compute_subnets_cidr"></a> [compute\_subnets\_cidr](#input\_compute\_subnets\_cidr) | Subnet CIDR block to launch the compute cluster host. | `list(string)` | <pre>[<br>  "10.10.10.0/24",<br>  "10.20.10.0/24",<br>  "10.30.10.0/24"<br>]</pre> | no |
| <a name="input_cos_instance_name"></a> [cos\_instance\_name](#input\_cos\_instance\_name) | Exiting COS instance name | `string` | `null` | no |
| <a name="input_enable_atracker"></a> [enable\_atracker](#input\_enable\_atracker) | Enable Activity tracker | `bool` | `true` | no |
| <a name="input_enable_deployer"></a> [enable\_deployer](#input\_enable\_deployer) | deployer should be only used for better deployment performance | `bool` | `false` | no |
| <a name="input_enable_cos_integration"></a> [enable\_cos\_integration](#input\_enable\_cos\_integration) | Integrate COS with HPC solution | `bool` | `true` | no |
| <a name="input_enable_client"></a> [enable\_client](#input\_enable\_client) | The solution supports multiple ways to connect to your HPC cluster for example, using client node, via VPN or direct connection. If connecting to the HPC cluster via VPN or direct connection, set this value to false. | `bool` | `true` | no |
| <a name="input_enable_vpc_flow_logs"></a> [enable\_vpc\_flow\_logs](#input\_enable\_vpc\_flow\_logs) | Enable Activity tracker | `bool` | `true` | no |
| <a name="input_enable_vpn"></a> [enable\_vpn](#input\_enable\_vpn) | The solution supports multiple ways to connect to your HPC cluster for example, using client node, via VPN or direct connection. If connecting to the HPC cluster via VPN, set this value to true. | `bool` | `false` | no |
| <a name="input_hpcs_instance_name"></a> [hpcs\_instance\_name](#input\_hpcs\_instance\_name) | Hyper Protect Crypto Service instance | `string` | `null` | no |
| <a name="input_ibmcloud_api_key"></a> [ibmcloud\_api\_key](#input\_ibmcloud\_api\_key) | IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required. | `string` | `null` | no |
| <a name="input_key_management"></a> [key\_management](#input\_key\_management) | null/key\_protect/hs\_crypto | `string` | `null` | no |
| <a name="input_client_ssh_keys"></a> [client\_ssh\_keys](#input\_client\_ssh\_keys) | The key pair to use to access the client host. | `list(string)` | n/a | yes |
| <a name="input_client_subnets_cidr"></a> [client\_subnets\_cidr](#input\_client\_subnets\_cidr) | Subnet CIDR block to launch the client host. | `list(string)` | <pre>[<br>  "10.0.0.0/24"<br>]</pre> | no |
| <a name="input_management_instances"></a> [management\_instances](#input\_management\_instances) | Number of instances to be launched for management. | `number` | `3` | no |
| <a name="input_max_compute_instances"></a> [max\_compute\_instances](#input\_max\_compute\_instances) | MaxNumber of instances to be launched for compute cluster. | `number` | `250` | no |
| <a name="input_min_compute_instances"></a> [min\_compute\_instances](#input\_min\_compute\_instances) | Min Number of instances to be launched for compute cluster. | `number` | `0` | no |
| <a name="input_network_cidr"></a> [network\_cidr](#input\_network\_cidr) | Network CIDR for the VPC. This is used to manage network ACL rules for cluster provisioning. | `string` | `"10.0.0.0/8"` | no |
| <a name="input_placement_strategy"></a> [placement\_strategy](#input\_placement\_strategy) | VPC placement groups to create (null / host\_spread / power\_spread) | `string` | `null` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters. | `string` | n/a | yes |
| <a name="input_protocol_instances"></a> [protocol\_instances](#input\_protocol\_instances) | Number of instances to be launched for protocol hosts. | `number` | `2` | no |
| <a name="input_protocol_subnets_cidr"></a> [protocol\_subnets\_cidr](#input\_protocol\_subnets\_cidr) | Subnet CIDR block to launch the storage cluster host. | `list(string)` | <pre>[<br>  "10.10.30.0/24",<br>  "10.20.30.0/24",<br>  "10.30.30.0/24"<br>]</pre> | no |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | String describing resource groups to create or reference | `string` | `null` | no |
| <a name="input_storage_instances"></a> [storage\_instances](#input\_storage\_instances) | Number of instances to be launched for storage cluster. | `number` | `3` | no |
| <a name="input_storage_ssh_keys"></a> [storage\_ssh\_keys](#input\_storage\_ssh\_keys) | The key pair to use to launch the storage cluster host. | `list(string)` | n/a | yes |
| <a name="input_storage_subnets_cidr"></a> [storage\_subnets\_cidr](#input\_storage\_subnets\_cidr) | Subnet CIDR block to launch the storage cluster host. | `list(string)` | <pre>[<br>  "10.10.20.0/24",<br>  "10.20.20.0/24",<br>  "10.30.20.0/24"<br>]</pre> | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc) | `string` | `null` | no |
| <a name="input_vpn_peer_address"></a> [vpn\_peer\_address](#input\_vpn\_peer\_address) | The peer public IP address to which the VPN will be connected. | `string` | `null` | no |
| <a name="input_vpn_peer_cidr"></a> [vpn\_peer\_cidr](#input\_vpn\_peer\_cidr) | The peer CIDRs (e.g., 192.168.0.0/24) to which the VPN will be connected. | `list(string)` | `null` | no |
| <a name="input_vpn_preshared_key"></a> [vpn\_preshared\_key](#input\_vpn\_preshared\_key) | The pre-shared key for the VPN. | `string` | `null` | no |
| <a name="input_zones"></a> [zones](#input\_zones) | Region where VPC will be created. To find your VPC region, use `ibmcloud is regions` command to find available regions. | `list(string)` | n/a | yes |

## Outputs

No outputs.
