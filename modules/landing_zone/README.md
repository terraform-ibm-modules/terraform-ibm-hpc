## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | >= 1.56.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_ibm"></a> [ibm](#provider\_ibm) | >= 1.56.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_landing_zone"></a> [landing\_zone](#module\_landing\_zone) | terraform-ibm-modules/landing-zone/ibm | 6.6.3 |

## Resources

| Name | Type |
|------|------|
| [ibm_is_subnet.subnet](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_subnet) | data source |
| [ibm_is_vpc.itself](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_vpc) | data source |
| [ibm_kms_key.kms_key](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/kms_key) | data source |
| [ibm_resource_instance.kms_instance](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/resource_instance) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bastion_subnets_cidr"></a> [bastion\_subnets\_cidr](#input\_bastion\_subnets\_cidr) | Subnet CIDR block to launch the bastion host. | `list(string)` | <pre>[<br/>  "10.0.0.0/24"<br/>]</pre> | no |
| <a name="input_compute_subnets_cidr"></a> [compute\_subnets\_cidr](#input\_compute\_subnets\_cidr) | Subnet CIDR block to launch the compute cluster host. | `list(string)` | <pre>[<br/>  "10.10.20.0/24",<br/>  "10.20.20.0/24",<br/>  "10.30.20.0/24"<br/>]</pre> | no |
| <a name="input_cos_expiration_days"></a> [cos\_expiration\_days](#input\_cos\_expiration\_days) | Specify the number of days after object creation to expire objects in COS buckets. | `number` | `30` | no |
| <a name="input_cos_instance_name"></a> [cos\_instance\_name](#input\_cos\_instance\_name) | Exiting COS instance name | `string` | `null` | no |
| <a name="input_enable_atracker"></a> [enable\_atracker](#input\_enable\_atracker) | Enable Activity tracker on COS | `bool` | `true` | no |
| <a name="input_enable_cos_integration"></a> [enable\_cos\_integration](#input\_enable\_cos\_integration) | Integrate COS with HPC solution | `bool` | `true` | no |
| <a name="input_enable_landing_zone"></a> [enable\_landing\_zone](#input\_enable\_landing\_zone) | Run landing zone module. | `bool` | `true` | no |
| <a name="input_enable_vpc_flow_logs"></a> [enable\_vpc\_flow\_logs](#input\_enable\_vpc\_flow\_logs) | Enable Activity tracker | `bool` | `true` | no |
| <a name="input_enable_vpn"></a> [enable\_vpn](#input\_enable\_vpn) | The solution supports multiple ways to connect to your HPC cluster for example, using bastion node, via VPN or direct connection. If connecting to the HPC cluster via VPN, set this value to true. | `bool` | `false` | no |
| <a name="input_key_management"></a> [key\_management](#input\_key\_management) | null/key\_protect | `string` | `null` | no |
| <a name="input_kms_instance_name"></a> [kms\_instance\_name](#input\_kms\_instance\_name) | Name of the Key Protect instance associated with the Key Management Service. The ID can be found under the details of the KMS, see [View key-protect ID](https://cloud.ibm.com/docs/key-protect?topic=key-protect-retrieve-instance-ID&interface=ui). | `string` | `null` | no |
| <a name="input_kms_key_name"></a> [kms\_key\_name](#input\_kms\_key\_name) | Provide the existing KMS encryption key name that you want to use for the IBM Cloud HPC cluster. (for example kms\_key\_name: my-encryption-key). | `string` | `null` | no |
| <a name="input_login_subnet_id"></a> [login\_subnet\_id](#input\_login\_subnet\_id) | List of existing subnet ID under the VPC, where the login/Bastion server will be provisioned. | `string` | `null` | no |
| <a name="input_network_cidr"></a> [network\_cidr](#input\_network\_cidr) | Network CIDR for the VPC. This is used to manage network ACL rules for cluster provisioning. | `string` | `"10.0.0.0/8"` | no |
| <a name="input_no_addr_prefix"></a> [no\_addr\_prefix](#input\_no\_addr\_prefix) | Set it as true, if you don't want to create address prefixes. | `bool` | n/a | yes |
| <a name="input_observability_logs_enable"></a> [observability\_logs\_enable](#input\_observability\_logs\_enable) | Set false to disable IBM Cloud Logs integration. If enabled, infrastructure and LSF application logs from Management/Compute Nodes will be ingested under COS bucket. | `bool` | `false` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters. | `string` | n/a | yes |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | String describing resource groups to create or reference | `string` | `null` | no |
| <a name="input_scc_enable"></a> [scc\_enable](#input\_scc\_enable) | Flag to enable SCC instance creation. If true, an instance of SCC (Security and Compliance Center) will be created. | `bool` | `false` | no |
| <a name="input_skip_flowlogs_s2s_auth_policy"></a> [skip\_flowlogs\_s2s\_auth\_policy](#input\_skip\_flowlogs\_s2s\_auth\_policy) | Skip auth policy between flow logs service and COS instance, set to true if this policy is already in place on account. | `bool` | `false` | no |
| <a name="input_ssh_keys"></a> [ssh\_keys](#input\_ssh\_keys) | The key pair to use to access the servers. | `list(string)` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | List of existing subnet IDs under the VPC, where the cluster will be provisioned. | `list(string)` | `null` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc) | `string` | `null` | no |
| <a name="input_zones"></a> [zones](#input\_zones) | Region where VPC will be created. To find your VPC region, use `ibmcloud is regions` command to find available regions. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bastion_subnets"></a> [bastion\_subnets](#output\_bastion\_subnets) | Bastion subnets |
| <a name="output_boot_volume_encryption_key"></a> [boot\_volume\_encryption\_key](#output\_boot\_volume\_encryption\_key) | Boot volume encryption key |
| <a name="output_compute_subnets"></a> [compute\_subnets](#output\_compute\_subnets) | Compute subnets |
| <a name="output_cos_buckets_data"></a> [cos\_buckets\_data](#output\_cos\_buckets\_data) | COS buckets data |
| <a name="output_cos_buckets_names"></a> [cos\_buckets\_names](#output\_cos\_buckets\_names) | Name of the COS Bucket created for SCC Instance |
| <a name="output_cos_instance_crns"></a> [cos\_instance\_crns](#output\_cos\_instance\_crns) | CRN of the COS instance created by Landing Zone Module |
| <a name="output_key_management_guid"></a> [key\_management\_guid](#output\_key\_management\_guid) | GUID for KMS instance |
| <a name="output_login_subnets"></a> [login\_subnets](#output\_login\_subnets) | Login subnets |
| <a name="output_protocol_subnets"></a> [protocol\_subnets](#output\_protocol\_subnets) | Protocol subnets |
| <a name="output_public_gateways"></a> [public\_gateways](#output\_public\_gateways) | Public Gateway IDs |
| <a name="output_resource_group_id"></a> [resource\_group\_id](#output\_resource\_group\_id) | Resource group ID |
| <a name="output_storage_subnets"></a> [storage\_subnets](#output\_storage\_subnets) | Storage subnets |
| <a name="output_subnets"></a> [subnets](#output\_subnets) | subnets |
| <a name="output_subnets_crn"></a> [subnets\_crn](#output\_subnets\_crn) | Subnets crn |
| <a name="output_vpc_cidr"></a> [vpc\_cidr](#output\_vpc\_cidr) | To fetch the vpc cidr |
| <a name="output_vpc_crn"></a> [vpc\_crn](#output\_vpc\_crn) | VPC CRN |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID |
| <a name="output_vpc_name"></a> [vpc\_name](#output\_vpc\_name) | VPC name |
