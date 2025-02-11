## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | >= 1.56.2 |
| <a name="requirement_template"></a> [template](#requirement\_template) | ~> 2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_ibm"></a> [ibm](#provider\_ibm) | 1.59.0 |
| <a name="provider_template"></a> [template](#provider\_template) | 2.2.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_compute_key"></a> [compute\_key](#module\_compute\_key) | ./../key | n/a |
| <a name="module_compute_sg"></a> [compute\_sg](#module\_compute\_sg) | terraform-ibm-modules/security-group/ibm | 2.6.2 |
| <a name="module_compute_sg_with_ldap_connection"></a> [compute\_sg\_with\_ldap\_connection](#module\_compute\_sg\_with\_ldap\_connection) | terraform-ibm-modules/security-group/ibm | 2.6.2 |
| <a name="module_do_management_candidate_vsi_configuration"></a> [do\_management\_candidate\_vsi\_configuration](#module\_do\_management\_candidate\_vsi\_configuration) | ./../../modules/null/remote_exec_script | n/a |
| <a name="module_do_management_vsi_configuration"></a> [do\_management\_vsi\_configuration](#module\_do\_management\_vsi\_configuration) | ./../../modules/null/remote_exec_script | n/a |
| <a name="module_generate_db_password"></a> [generate\_db\_password](#module\_generate\_db\_password) | ../../modules/security/password | n/a |
| <a name="module_ldap_vsi"></a> [ldap\_vsi](#module\_ldap\_vsi) | terraform-ibm-modules/landing-zone-vsi/ibm | 4.5.0 |
| <a name="module_login_vsi"></a> [login\_vsi](#module\_login\_vsi) | terraform-ibm-modules/landing-zone-vsi/ibm | 4.5.0 |
| <a name="module_lsf_entitlement"></a> [lsf\_entitlement](#module\_lsf\_entitlement) | ./../../modules/null/remote_exec | n/a |
| <a name="module_management_candidate_vsi"></a> [management\_candidate\_vsi](#module\_management\_candidate\_vsi) | terraform-ibm-modules/landing-zone-vsi/ibm | 4.5.0 |
| <a name="module_management_vsi"></a> [management\_vsi](#module\_management\_vsi) | terraform-ibm-modules/landing-zone-vsi/ibm | 4.5.0 |
| <a name="module_nfs_storage_sg"></a> [nfs\_storage\_sg](#module\_nfs\_storage\_sg) | terraform-ibm-modules/security-group/ibm | 2.6.2 |
| <a name="module_ssh_connection_to_login_node_via_cluster_nodes"></a> [ssh\_connection\_to\_login\_node\_via\_cluster\_nodes](#module\_ssh\_connection\_to\_login\_node\_via\_cluster\_nodes) | terraform-ibm-modules/security-group/ibm | 2.6.2 |
| <a name="module_ssh_key"></a> [ssh\_key](#module\_ssh\_key) | ./../key | n/a |
| <a name="module_wait_management_candidate_vsi_booted"></a> [wait\_management\_candidate\_vsi\_booted](#module\_wait\_management\_candidate\_vsi\_booted) | ./../../modules/null/remote_exec | n/a |
| <a name="module_wait_management_vsi_booted"></a> [wait\_management\_vsi\_booted](#module\_wait\_management\_vsi\_booted) | ./../../modules/null/remote_exec | n/a |
| <a name="module_wait_worker_vsi_booted"></a> [wait\_worker\_vsi\_booted](#module\_wait\_worker\_vsi\_booted) | ./../../modules/null/remote_exec | n/a |
| <a name="module_worker_vsi"></a> [worker\_vsi](#module\_worker\_vsi) | terraform-ibm-modules/landing-zone-vsi/ibm | 4.5.0 |

## Resources

| Name | Type |
|------|------|
| [ibm_is_image.compute](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_image) | data source |
| [ibm_is_image.ldap_vsi_image](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_image) | data source |
| [ibm_is_image.login](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_image) | data source |
| [ibm_is_image.management](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_image) | data source |
| [ibm_is_instance_profile.management_node](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_instance_profile.worker_node](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_instance_profile) | data source |
| [ibm_is_region.region](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_region) | data source |
| [ibm_is_ssh_key.bastion](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_ssh_key) | data source |
| [ibm_is_ssh_key.compute](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_ssh_key) | data source |
| [template_file.ldap_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.login_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.management_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.management_values](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.worker_user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app_center_gui_pwd"></a> [app\_center\_gui\_pwd](#input\_app\_center\_gui\_pwd) | Password for IBM Spectrum LSF Application Center GUI. Note: Password should be at least 8 characters, must have one number, one lowercase letter, one uppercase letter, and at least one special character. | `string` | `""` | no |
| <a name="input_app_center_high_availability"></a> [app\_center\_high\_availability](#input\_app\_center\_high\_availability) | Set to false to disable the IBM Spectrum LSF Application Center GUI High Availability (default: true) . | `bool` | `true` | no |
| <a name="input_bastion_fip"></a> [bastion\_fip](#input\_bastion\_fip) | Bastion FIP. | `string` | n/a | yes |
| <a name="input_bastion_instance_name"></a> [bastion\_instance\_name](#input\_bastion\_instance\_name) | Bastion instance name. | `string` | `null` | no |
| <a name="input_bastion_private_key_content"></a> [bastion\_private\_key\_content](#input\_bastion\_private\_key\_content) | Bastion private key content | `string` | n/a | yes |
| <a name="input_bastion_public_key_content"></a> [bastion\_public\_key\_content](#input\_bastion\_public\_key\_content) | Bastion security group id. | `string` | `null` | no |
| <a name="input_bastion_security_group_id"></a> [bastion\_security\_group\_id](#input\_bastion\_security\_group\_id) | Bastion security group id. | `string` | n/a | yes |
| <a name="input_bastion_subnets"></a> [bastion\_subnets](#input\_bastion\_subnets) | Subnets to launch the bastion host. | <pre>list(object({<br>    name = string<br>    id   = string<br>    zone = string<br>    cidr = string<br>  }))</pre> | `[]` | no |
| <a name="input_boot_volume_encryption_key"></a> [boot\_volume\_encryption\_key](#input\_boot\_volume\_encryption\_key) | CRN of boot volume encryption key | `string` | `null` | no |
| <a name="input_ce_project_guid"></a> [ce\_project\_guid](#input\_ce\_project\_guid) | The GUID of the Code Engine Project associated to this cluster Reservation | `string` | n/a | yes |
| <a name="input_cloud_logs_ingress_private_endpoint"></a> [cloud\_logs\_ingress\_private\_endpoint](#input\_cloud\_logs\_ingress\_private\_endpoint) | String describing resource groups to create or reference | `string` | `null` | no |
| <a name="input_cloud_monitoring_access_key"></a> [cloud\_monitoring\_access\_key](#input\_cloud\_monitoring\_access\_key) | IBM Cloud Monitoring access key for agents to use | `string` | n/a | yes |
| <a name="input_cloud_monitoring_ingestion_url"></a> [cloud\_monitoring\_ingestion\_url](#input\_cloud\_monitoring\_ingestion\_url) | IBM Cloud Monitoring ingestion url for agents to use | `string` | n/a | yes |
| <a name="input_cloud_monitoring_prws_key"></a> [cloud\_monitoring\_prws\_key](#input\_cloud\_monitoring\_prws\_key) | IBM Cloud Monitoring Prometheus Remote Write ingestion key | `string` | n/a | yes |
| <a name="input_cloud_monitoring_prws_url"></a> [cloud\_monitoring\_prws\_url](#input\_cloud\_monitoring\_prws\_url) | IBM Cloud Monitoring Prometheus Remote Write ingestion url | `string` | n/a | yes |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | Ensure that you have received the cluster ID from IBM technical sales. A unique identifer for HPC cluster used by IBM Cloud HPC to differentiate different HPC clusters within the same contract. This can be up to 39 alphanumeric characters including the underscore (\_), the hyphen (-), and the period (.) characters. You cannot change the cluster ID after deployment. | `string` | n/a | yes |
| <a name="input_cluster_user"></a> [cluster\_user](#input\_cluster\_user) | Linux user for cluster administration. | `string` | n/a | yes |
| <a name="input_compute_image_name"></a> [compute\_image\_name](#input\_compute\_image\_name) | Image name to use for provisioning the compute cluster instances. | `string` | `"hpcaas-lsf10-rhel810-compute-v8"` | no |
| <a name="input_compute_private_key_content"></a> [compute\_private\_key\_content](#input\_compute\_private\_key\_content) | Compute private key content | `string` | n/a | yes |
| <a name="input_compute_ssh_keys"></a> [compute\_ssh\_keys](#input\_compute\_ssh\_keys) | The key pair to use to launch the compute host. | `list(string)` | n/a | yes |
| <a name="input_compute_subnets"></a> [compute\_subnets](#input\_compute\_subnets) | Subnets to launch the compute host. | <pre>list(object({<br>    name = string<br>    id   = string<br>    zone = string<br>    cidr = string<br>    crn  = string<br>  }))</pre> | `[]` | no |
| <a name="input_contract_id"></a> [contract\_id](#input\_contract\_id) | Ensure that you have received the contract ID from IBM technical sales. Contract ID is a unique identifier to distinguish different IBM Cloud HPC service agreements. It must start with a letter and can only contain letters, numbers, hyphens (-), or underscores (\_). | `string` | n/a | yes |
| <a name="input_db_admin_password"></a> [db\_admin\_password](#input\_db\_admin\_password) | The IBM Cloud Database for MySQL password required to reference the PAC database. | `string` | `null` | no |
| <a name="input_db_instance_info"></a> [db\_instance\_info](#input\_db\_instance\_info) | The IBM Cloud Database for MySQL information required to reference the PAC database. | <pre>object({<br>    id             = string<br>    admin_user     = string<br>    hostname       = string<br>    port           = number<br>    certificate    = string<br>  })</pre> | `null` | no |
| <a name="input_dedicated_host_id"></a> [dedicated\_host\_id](#input\_dedicated\_host\_id) | Dedicated Host for the worker nodes | `string` | `null` | no |
| <a name="input_dns_domain_names"></a> [dns\_domain\_names](#input\_dns\_domain\_names) | IBM Cloud HPC DNS domain names. | <pre>object({<br>    compute = string<br>    #storage  = string<br>    #protocol = string<br>  })</pre> | <pre>{<br>  "compute": "comp.com",<br>  "protocol": "ces.com",<br>  "storage": "strg.com"<br>}</pre> | no |
| <a name="input_enable_app_center"></a> [enable\_app\_center](#input\_enable\_app\_center) | Set to true to enable the IBM Spectrum LSF Application Center GUI (default: false). [System requirements](https://www.ibm.com/docs/en/slac/10.2.0?topic=requirements-system-102-fix-pack-14) for IBM Spectrum LSF Application Center Version 10.2 Fix Pack 14. | `bool` | `false` | no |
| <a name="input_enable_dedicated_host"></a> [enable\_dedicated\_host](#input\_enable\_dedicated\_host) | Set this option to true to enable dedicated hosts for the VSI created for workload servers, with the default value set to false. | `bool` | `false` | no |
| <a name="input_enable_ldap"></a> [enable\_ldap](#input\_enable\_ldap) | Set this option to true to enable LDAP for IBM Cloud HPC, with the default value set to false. | `bool` | `false` | no |
| <a name="input_existing_kms_instance_guid"></a> [existing\_kms\_instance\_guid](#input\_existing\_kms\_instance\_guid) | GUID of boot volume encryption key | `string` | `null` | no |
| <a name="input_file_share"></a> [file\_share](#input\_file\_share) | VPC file share mount points considering the ip address and the file share name | `list(string)` | n/a | yes |
| <a name="input_hyperthreading_enabled"></a> [hyperthreading\_enabled](#input\_hyperthreading\_enabled) | Setting this to true will enable hyper-threading in the compute nodes of the cluster (default). Otherwise, hyper-threading will be disabled. | `bool` | `true` | no |
| <a name="input_ibm_customer_number"></a> [ibm\_customer\_number](#input\_ibm\_customer\_number) | Comma-separated list of the IBM Customer Number(s) (ICN) that is used for the Bring Your Own License (BYOL) entitlement check. For more information on how to find your ICN, see [What is my IBM Customer Number (ICN)?](https://www.ibm.com/support/pages/what-my-ibm-customer-number-icn). | `string` | `null` | no |
| <a name="input_ibmcloud_api_key"></a> [ibmcloud\_api\_key](#input\_ibmcloud\_api\_key) | IBM Cloud API Key that will be used for authentication in scripts run in this module. Only required if certain options are required. | `string` | `null` | no |
| <a name="input_kms_encryption_enabled"></a> [kms\_encryption\_enabled](#input\_kms\_encryption\_enabled) | Enable Key management | `bool` | `true` | no |
| <a name="input_ldap_admin_password"></a> [ldap\_admin\_password](#input\_ldap\_admin\_password) | The LDAP administrative password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@\_+:) are required. It is important to avoid including the username in the password for enhanced security.[This value is ignored for an existing LDAP server]. | `string` | `""` | no |
| <a name="input_ldap_basedns"></a> [ldap\_basedns](#input\_ldap\_basedns) | The dns domain name is used for configuring the LDAP server. If an LDAP server is already in existence, ensure to provide the associated DNS domain name. | `string` | `"hpcaas.com"` | no |
| <a name="input_ldap_primary_ip"></a> [ldap\_primary\_ip](#input\_ldap\_primary\_ip) | List of LDAP primary IPs. | `list(string)` | n/a | yes |
| <a name="input_ldap_server"></a> [ldap\_server](#input\_ldap\_server) | Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created. | `string` | `"null"` | no |
| <a name="input_ldap_server_cert"></a> [ldap\_server\_cert](#input\_ldap\_server\_cert) | Provide the existing LDAP server certificate. If not provided, the value should be set to 'null'. | `string` | `"null"` | no |
| <a name="input_ldap_user_name"></a> [ldap\_user\_name](#input\_ldap\_user\_name) | Custom LDAP User for performing cluster operations. Note: Username should be between 4 to 32 characters, (any combination of lowercase and uppercase letters).[This value is ignored for an existing LDAP server] | `string` | `""` | no |
| <a name="input_ldap_user_password"></a> [ldap\_user\_password](#input\_ldap\_user\_password) | The LDAP user password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@\_+:) are required.It is important to avoid including the username in the password for enhanced security.[This value is ignored for an existing LDAP server]. | `string` | `""` | no |
| <a name="input_ldap_vsi_osimage_name"></a> [ldap\_vsi\_osimage\_name](#input\_ldap\_vsi\_osimage\_name) | Image name to be used for provisioning the LDAP instances. | `string` | `"ibm-ubuntu-22-04-4-minimal-amd64-3"` | no |
| <a name="input_ldap_vsi_profile"></a> [ldap\_vsi\_profile](#input\_ldap\_vsi\_profile) | Profile to be used for LDAP virtual server instance. | `string` | `"cx2-2x4"` | no |
| <a name="input_login_image_name"></a> [login\_image\_name](#input\_login\_image\_name) | Image name to use for provisioning the login instance. | `string` | `"hpcaas-lsf10-rhel810-compute-v8"` | no |
| <a name="input_login_node_instance_type"></a> [login\_node\_instance\_type](#input\_login\_node\_instance\_type) | Specify the virtual server instance profile type to be used to create the login node for the IBM Cloud HPC cluster. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles). | `string` | `"bx2-2x8"` | no |
| <a name="input_login_private_ips"></a> [login\_private\_ips](#input\_login\_private\_ips) | Login private IPs | `string` | n/a | yes |
| <a name="input_management_image_name"></a> [management\_image\_name](#input\_management\_image\_name) | Image name to use for provisioning the management cluster instances. | `string` | `"hpcaas-lsf10-rhel810-v12"` | no |
| <a name="input_management_node_count"></a> [management\_node\_count](#input\_management\_node\_count) | Number of management nodes. This is the total number of management nodes. Enter a value between 1 and 10. | `number` | `3` | no |
| <a name="input_management_node_instance_type"></a> [management\_node\_instance\_type](#input\_management\_node\_instance\_type) | Specify the virtual server instance profile type to be used to create the management nodes for the IBM Cloud HPC cluster. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles). | `string` | `"bx2-16x64"` | no |
| <a name="input_mount_path"></a> [mount\_path](#input\_mount\_path) | Provide the path for the vpc file share to be mounted on to the HPC Cluster nodes | <pre>list(object({<br>    mount_path = string,<br>    size       = optional(number),<br>    iops       = optional(number),<br>    nfs_share  = optional(string)<br>  }))</pre> | n/a | yes |
| <a name="input_observability_logs_enable_for_compute"></a> [observability\_logs\_enable\_for\_compute](#input\_observability\_logs\_enable\_for\_compute) | Set false to disable IBM Cloud Logs integration. If enabled, infrastructure and LSF application logs from Compute Nodes will be ingested. | `bool` | `false` | no |
| <a name="input_observability_logs_enable_for_management"></a> [observability\_logs\_enable\_for\_management](#input\_observability\_logs\_enable\_for\_management) | Set false to disable IBM Cloud Logs integration. If enabled, infrastructure and LSF application logs from Management Nodes will be ingested. | `bool` | `false` | no |
| <a name="input_observability_monitoring_enable"></a> [observability\_monitoring\_enable](#input\_observability\_monitoring\_enable) | Set true to enable IBM Cloud Monitoring instance provisioning. | `bool` | `false` | no |
| <a name="input_observability_monitoring_on_compute_nodes_enable"></a> [observability\_monitoring\_on\_compute\_nodes\_enable](#input\_observability\_monitoring\_on\_compute\_nodes\_enable) | Set true to enable IBM Cloud Monitoring on Compute Nodes. | `bool` | `false` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | A unique identifier for resources. Must begin with a letter and end with a letter or number. This prefix will be prepended to any resources provisioned by this template. Prefixes must be 16 or fewer characters. | `string` | n/a | yes |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | String describing resource groups to create or reference | `string` | `null` | no |
| <a name="input_share_path"></a> [share\_path](#input\_share\_path) | Provide the exact path to where the VPC file share needs to be mounted | `string` | n/a | yes |
| <a name="input_solution"></a> [solution](#input\_solution) | Provide the value for the solution that is needed for the support of lsf and HPC | `string` | `"lsf"` | no |
| <a name="input_ssh_keys"></a> [ssh\_keys](#input\_ssh\_keys) | The key pair to use to access the host. | `list(string)` | n/a | yes |
| <a name="input_storage_security_group_id"></a> [storage\_security\_group\_id](#input\_storage\_security\_group\_id) | Existing Scale storage security group id | `string` | `null` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of an existing VPC in which the cluster resources will be deployed. | `string` | n/a | yes |
| <a name="input_worker_node_instance_type"></a> [worker\_node\_instance\_type](#input\_worker\_node\_instance\_type) | The minimum number of worker nodes refers to the static worker nodes provisioned during cluster creation. The solution supports various instance types, so specify the node count based on the requirements of each instance profile. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles). | <pre>list(object({<br>    count         = number<br>    instance_type = string<br>  }))</pre> | <pre>[<br>  {<br>    "count": 3,<br>    "instance_type": "bx2-4x16"<br>  },<br>  {<br>    "count": 0,<br>    "instance_type": "cx2-8x16"<br>  }<br>]</pre> | no |
| <a name="input_worker_node_max_count"></a> [worker\_node\_max\_count](#input\_worker\_node\_max\_count) | The maximum number of worker nodes that can be deployed in the Spectrum LSF cluster. In order to use the [Resource Connector](https://www.ibm.com/docs/en/spectrum-lsf/10.1.0?topic=lsf-resource-connnector) feature to dynamically create and delete worker nodes based on workload demand, the value selected for this parameter must be larger than worker\_node\_min\_count. If you plan to deploy only static worker nodes in the LSF cluster, e.g., when using Spectrum Scale storage, the value for this parameter should be equal to worker\_node\_min\_count. Enter a value in the range 1 - 500. | `number` | `10` | no |
| <a name="input_zones"></a> [zones](#input\_zones) | Region where VPC will be created. To find your VPC region, use `ibmcloud is regions` command to find available regions. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_compute_private_key_content"></a> [compute\_private\_key\_content](#output\_compute\_private\_key\_content) | Compute private key content |
| <a name="output_compute_public_key_content"></a> [compute\_public\_key\_content](#output\_compute\_public\_key\_content) | Compute public key content |
| <a name="output_compute_sg_id"></a> [compute\_sg\_id](#output\_compute\_sg\_id) | Compute SG id |
| <a name="output_image_map_entry_found"></a> [image\_map\_entry\_found](#output\_image\_map\_entry\_found) | Available if the image name provided is located within the image map |
| <a name="output_ldap_server"></a> [ldap\_server](#output\_ldap\_server) | LDAP server IP |
| <a name="output_ldap_vsi_data"></a> [ldap\_vsi\_data](#output\_ldap\_vsi\_data) | Login VSI data |
| <a name="output_login_vsi_data"></a> [login\_vsi\_data](#output\_login\_vsi\_data) | Login VSI data |
| <a name="output_management_candidate_vsi_data"></a> [management\_candidate\_vsi\_data](#output\_management\_candidate\_vsi\_data) | Management candidate VSI data |
| <a name="output_management_vsi_data"></a> [management\_vsi\_data](#output\_management\_vsi\_data) | Management VSI data |
| <a name="output_worker_vsi_data"></a> [worker\_vsi\_data](#output\_worker\_vsi\_data) | Static worker VSI data |
