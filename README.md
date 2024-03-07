# IBM Cloud HPC
Repository for the IBM Cloud HPC project with IBM Spectrum schedulers

## Deploying the environment using CLI:

### Initial configuration:

```
$ ibmcloud iam api-key-create user-api-key --file ~/.ibm-api-key.json -d "ibmcloud_api_key"
$ cat ~/.ibm-api-key.json | jq -r ."apikey"
# copy your apikey
```

### 1. Deployment with Catalog CLI on IBM Cloud

Use the below IBM Cloud CLI command to create catalog workspace with specific product version. Update the custom configuration and cluster name as per the requirement.
Note: IBM Catalog management plug-in must be pre-installed. [Learn more](https://cloud.ibm.com/docs/cli?topic=cli-manage-catalogs-plugin)

```
$ cp sample/configs/hpc_catalog_values.json values.json
$ vim values.json
# Paste your API key and other mandatory parameters value for IBM Cloud HPC cluster
# Login to the IBM Cloud CLI
$ ibmcloud catalog install --vl <version-locator-value> --override-values values.json

Note: You can retrieve the <version-locator-value> by accessing the CLI section within the Deployment options of the IBM Cloud HPC tile.

It bears resemblance to something along these lines:
$ ibmcloud catalog install --vl 1082e7d2-5e2f-0a11-a3bc-f88a8e1931fc.c7645085-5f49-4d5f-8786-45ac376e60fe-global --override-values values.json
Attempting install of IBM Cloud HPC version x.x.x...
Schematics workspace: https://cloud.ibm.com/schematics/workspaces/us-south.workspace.globalcatalog-collection.40b1c1e4/jobs?region=
Workspace status: DRAFT
Workspace status: INACTIVE
Workspace status: INPROGRESS
Workspace status: ACTIVE
Installation successful
OK
```

You can refer the Schematics workspace url (next to Schematics workspace:) as part of the install command output.

### 2. Deployment with Schematics CLI on IBM Cloud

**Note**: You also need to generate GitHub token if you use private GitHub repository.

```
$ cp sample/configs/hpc_schematics_values.json values.json
$ vim values.json
# Paste your API key and other mandatory parameters value for IBM Cloud HPC cluster
# Login to the IBM Cloud CLI
$ ibmcloud schematics workspace new -f values.json --github-token xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
$ ibmcloud schematics workspace list
Name               ID                                            Description   Status     Frozen
hpcc-cluster       us-east.workspace.hpcc-cluster.7cbc3f6b       INACTIVE      False
OK

$ ibmcloud schematics plan --id us-east.workspace.hpcc-cluster.7cbc3f6b
Activity ID  51b6330e913d23636d706b084755a737
OK

$ ibmcloud schematics apply --id us-east.workspace.hpcc-cluster.7cbc3f6b
Do you really want to perform this action? [y/N]> y
Activity ID b0a909030f071f51d6ceb48b62ee1671
OK

$ ibmcloud schematics logs --id us-east.workspace.hpcc-cluster.7cbc3f6b
...
 2023/06/05 22:14:29 Terraform apply | Apply complete! Resources: 41 added, 0 changed, 0 destroyed.
 2023/06/05 22:14:29 Terraform apply | 
 2023/06/05 22:14:29 Terraform apply | Outputs:
 2023/06/05 22:14:29 Terraform apply | 
 2023/06/05 22:14:29 Terraform apply | image_map_entry_found = "true --  - hpcaas-lsf10-rhel86-v1"
 2023/06/05 22:14:29 Terraform apply | region_name = "us-east"
 2023/06/05 22:14:29 Terraform apply | ssh_command = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J vpcuser@150.239.215.145 lsfadmin@10.241.0.4"
 2023/06/05 22:14:29 Terraform apply | vpc_name = "dv-hpcaas-vpc --  - r014-e7485f03-6797-4633-b140-2822ce8e1893"
 2023/06/05 22:14:29 Command finished successfully.
OK
```

### Accessing the deployed environment:

* Connect to an LSF login node through SSH by using the `ssh_to_login_node` command from the Schematics log output.
```
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J vpcuser@<floating_IP_address> lsfadmin@<login_node_IP_address>
```
* where `floating_IP_address` is the floating IP address for the bastion node and `login_node_IP_address` is the IP address for the login node.

### Steps to access the Application Center GUI/Dashboard:

* Open a new command line terminal.
* Connect to an LSF management node through SSH by using the `application_center` command from the Schematics log output.

```
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -L 8443:localhost:8443 -L 6080:localhost:6080 -J vpcuser@><floating_IP_address> lsfadmin@<management_node_IP_address>
```
* where `floating_IP_address` is the floating IP address for the bastion node and `management_node_IP_address` is the IP address for the management node.

* Open a browser on the local machine, and run https://localhost:8443 

* To access the Application Center GUI, enter the password you configured when you created your workspace and the default user as "lsfadmin".

* If LDAP is enabled, you can access the LSF Application Center using the LDAP username and password that you configured during IBM Cloud® HPC cluster deployment or using an existing LDAP username and password.


### Steps to validate the OpenLDAP:
* Connect to your OpenLDAP server through SSH by using the `ssh_to_ldap_node` command from the Schematics log output.

```
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -J vpcuser@<floatingg_IP_address> ubuntu@<LDAP_server_IP>
```
* where `floating_IP_address` is the floating IP address for the bastion node and `LDAP_server_IP` is the IP address for the OpenLDAP node.

* Verifiy the LDAP service status:

```
systemctl status slapd
```

* Verify the LDAP groups and users created:

```
ldapsearch -Q -LLL -Y EXTERNAL -H ldapi:///
```

* Submit a Job from HPC cluster Management node with LDAP user : Log into the management node using the `ssh_to_management_node` value as shown as part of output section of Schematics job log:

```
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J vpcuser@<floating_IP_address> lsfadmin@<management_node_IP_address>
```
* where `floating_IP_address` is the floating IP address for the bastion node and `management_node_IP_address` is the IP address for the management node.

* Switch to the LDAP user (for example, switch to lsfuser05):

```
[lsfadmin@hpccluster-mgmt-1 ~]$ su lsfuser05
Password:
[lsfuser05@hpccluster-mgmt-1 lsfadmin]# 
```

* Submit an LSF job as the LDAP user:

```
[lsfuser05@hpccluster-mgmt-1 lsfadmin]$ bsub -J myjob[1-4] -R "rusage[mem=2G]" sleep 10
Job <1> is submitted to default queue <normal>.
```

### Cleaning up the deployed environment:

If you no longer need your deployed IBM Cloud HPC cluster, you can clean it up from your environment. The process is threefold: ensure that the cluster is free of running jobs or working compute nodes, destroy all the associated VPC resources and remove them from your IBM Cloud account, and remove the project from the IBM Cloud console.

**Note**: Ensuring that the cluster is free of running jobs and working compute nodes

Ensure that it is safe to destroy resources:

1. As the `lsfadmin` user, close all LSF queues and kill all jobs:
   ```
    badmin qclose all
    bkill -u all 0
    ```

2. Wait ten minutes (this is the default idle time), and then check for running jobs:
    ```
    bjobs -u all
    ```

   Look for a `No unfinished job found` message.


3. Check that there are no compute nodes (only management nodes should be listed):
   ```
    bhosts -w
   ```

If the cluster has no running jobs or compute nodes, then it is safe to destroy resources from this environment.

#### Destroying resources

1. In the IBM Cloud console, from the **Schematics > Workspaces** view, select **Actions > Destroy resources** > **Confirm** the action by entering the workspace name in the text box and click Destroy to delete all the related VPC resources that were deployed.
2. If you select the option to destroy resources, decide whether you want to destroy all of them. This action cannot be undone.
3. Confirm the action by entering the workspace name in the text box and click **Destroy**.
You can now safely remove the resources from your account.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0, <1.6.0 |
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | >= 1.56.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_http"></a> [http](#provider\_http) | 3.4.1 |
| <a name="provider_ibm"></a> [ibm](#provider\_ibm) | 1.62.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_hpc"></a> [hpc](#module\_hpc) | ./solutions/hpc | n/a |
| <a name="module_ipvalidation_cluster_subnet"></a> [ipvalidation\_cluster\_subnet](#module\_ipvalidation\_cluster\_subnet) | ./modules/custom/subnet_cidr_check | n/a |
| <a name="module_ipvalidation_login_subnet"></a> [ipvalidation\_login\_subnet](#module\_ipvalidation\_login\_subnet) | ./modules/custom/subnet_cidr_check | n/a |

## Resources

| Name | Type |
|------|------|
| [http_http.contract_id_validation](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [ibm_iam_auth_token.auth_token](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/iam_auth_token) | data source |
| [ibm_is_public_gateways.public_gateways](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_public_gateways) | data source |
| [ibm_is_region.region](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_region) | data source |
| [ibm_is_subnet.existing_login_subnet](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_subnet) | data source |
| [ibm_is_subnet.existing_subnet](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_subnet) | data source |
| [ibm_is_vpc.existing_vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_vpc) | data source |
| [ibm_is_vpc.vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_vpc) | data source |
| [ibm_is_vpc_address_prefixes.existing_vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_vpc_address_prefixes) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app_center_high_availability"></a> [app\_center\_high\_availability](#input\_app\_center\_high\_availability) | Set to true to enable the IBM Spectrum LSF Application Center GUI (default: false) High Availability. | `bool` | `false` | no |
| <a name="input_TF_PARALLELISM"></a> [TF\_PARALLELISM](#input\_TF\_PARALLELISM) | Parallelism/ concurrent operations limit. Valid values are between 1 and 256, both inclusive. [Learn more](https://www.terraform.io/docs/internals/graph.html#walking-the-graph). | `string` | `"250"` | no |
| <a name="input_TF_VALIDATION_SCRIPT_FILES"></a> [TF\_VALIDATION\_SCRIPT\_FILES](#input\_TF\_VALIDATION\_SCRIPT\_FILES) | List of script file names used by validation test suites. If provided, these scripts will be executed as part of validation test suites execution. | `list(string)` | `[]` | no |
| <a name="input_TF_VERSION"></a> [TF\_VERSION](#input\_TF\_VERSION) | The version of the Terraform engine that's used in the Schematics workspace. | `string` | `"1.4"` | no |
| <a name="input_app_center_gui_pwd"></a> [app\_center\_gui\_pwd](#input\_app\_center\_gui\_pwd) | Password for IBM Spectrum LSF Application Center GUI. Note: Password should be at least 8 characters, must have one number, one lowercase letter, one uppercase letter, and at least one special character. | `string` | `""` | no |
| <a name="input_bastion_ssh_keys"></a> [bastion\_ssh\_keys](#input\_bastion\_ssh\_keys) | List of names of the SSH keys that is configured in your IBM Cloud account, used to establish a connection to the IBM Cloud HPC bastion node. Ensure that the SSH key is present in the same resource group and region where the cluster is being provisioned. If you do not have an SSH key in your IBM Cloud account, create one by according to [SSH Keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys). | `list(string)` | n/a | yes |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | Ensure that you have received the cluster ID from IBM technical sales. A unique identifer for HPC cluster used by IBM Cloud HPC to differentiate different HPC clusters within the same contract. This can be up to 39 alphanumeric characters including the underscore (\_), the hyphen (-), and the period (.) characters. You cannot change the cluster ID after deployment. | `string` | n/a | yes |
| <a name="input_cluster_prefix"></a> [cluster\_prefix](#input\_cluster\_prefix) | Prefix that is used to name the IBM Cloud HPC cluster and IBM Cloud resources that are provisioned to build the IBM Cloud HPC cluster instance. You cannot create more than one instance of the IBM Cloud HPC cluster with the same name. Ensure that the name is unique. | `string` | `"hpcaas"` | no |
| <a name="input_cluster_subnet_ids"></a> [cluster\_subnet\_ids](#input\_cluster\_subnet\_ids) | List of existing subnet IDs under the VPC, where the cluster will be provisioned. Two subnet ids are required as input value and supported zones for eu-de are eu-de-2, eu-de-3 and for us-east us-east-1, us-east-3. The management nodes and file storage shares will be deployed to the first zone in the list. Compute nodes will be deployed across both first and second zones, where the first zone in the list will be considered as the most preferred zone for compute nodes deployment. | `list(string)` | `[]` | no |
| <a name="input_compute_image_name"></a> [compute\_image\_name](#input\_compute\_image\_name) | Name of the custom image that you want to use to create virtual server instances in your IBM Cloud account to deploy the IBM Cloud HPC cluster dynamic compute nodes. By default, the solution uses a RHEL 8-6 OS image with additional software packages mentioned [here](https://cloud.ibm.com/docs/hpc-spectrum-LSF#create-custom-image). The solution also offers, Ubuntu 22-04 OS base image (hpcaas-lsf10-ubuntu2204-compute-v1). If you would like to include your application-specific binary files, follow the instructions in [ Planning for custom images ](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the IBM Cloud HPC cluster through this offering. | `string` | `"hpcaas-lsf10-rhel88-compute-v2"` | no |
| <a name="input_compute_ssh_keys"></a> [compute\_ssh\_keys](#input\_compute\_ssh\_keys) | List of names of the SSH keys that is configured in your IBM Cloud account, used to establish a connection to the IBM Cloud HPC cluster node. Ensure that the SSH key is present in the same resource group and region where the cluster is being provisioned. If you do not have an SSH key in your IBM Cloud account, create one by according to [SSH Keys](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys). | `list(string)` | n/a | yes |
| <a name="input_contract_id"></a> [contract\_id](#input\_contract\_id) | Ensure that you have received the contract ID from IBM technical sales. Contract ID is a unique identifier to distinguish different IBM Cloud HPC service agreements. It must start with a letter and can only contain letters, numbers, hyphens (-), or underscores (\_). | `string` | n/a | yes |
| <a name="input_cos_instance_name"></a> [cos\_instance\_name](#input\_cos\_instance\_name) | Provide the name of the existing cos instance to store vpc flow logs. | `string` | `null` | no |
| <a name="input_custom_file_shares"></a> [custom\_file\_shares](#input\_custom\_file\_shares) | Mount points and sizes in GB and IOPS range of file shares that can be used to customize shared file storage layout. Provide the details for up to 5 shares. Each file share size in GB supports different range of IOPS. For more information, see [file share IOPS value](https://cloud.ibm.com/docs/vpc?topic=vpc-file-storage-profiles&interface=ui). | <pre>list(object({<br>    mount_path = string,<br>    size       = number,<br>    iops       = number<br>  }))</pre> | <pre>[<br>  {<br>    "iops": 2000,<br>    "mount_path": "/mnt/binaries",<br>    "size": 100<br>  },<br>  {<br>    "iops": 6000,<br>    "mount_path": "/mnt/data",<br>    "size": 100<br>  }<br>]</pre> | no |
| <a name="input_dns_custom_resolver_id"></a> [dns\_custom\_resolver\_id](#input\_dns\_custom\_resolver\_id) | Provide the id of existing IBM Cloud DNS custom resolver to skip creating a new custom resolver. Note: A VPC can be associated only to a single custom resolver, please provide the id of custom resolver if it is already associated to the VPC. | `string` | `null` | no |
| <a name="input_dns_domain_names"></a> [dns\_domain\_names](#input\_dns\_domain\_names) | IBM Cloud DNS Services domain name to be used for the IBM Cloud HPC cluster. | <pre>object({<br>    compute = string<br>    #storage  = string<br>    #protocol = string<br>  })</pre> | <pre>{<br>  "compute": "hpcaas.com"<br>}</pre> | no |
| <a name="input_dns_instance_id"></a> [dns\_instance\_id](#input\_dns\_instance\_id) | Provide the id of existing IBM Cloud DNS services domain to skip creating a new DNS service instance name. Note: If dns\_instance\_id is not equal to null, a new dns zone will be created under the existing dns service instance. | `string` | `null` | no |
| <a name="input_enable_app_center"></a> [enable\_app\_center](#input\_enable\_app\_center) | Set to true to enable the IBM Spectrum LSF Application Center GUI (default: false). [System requirements](https://www.ibm.com/docs/en/slac/10.2.0?topic=requirements-system-102-fix-pack-14) for IBM Spectrum LSF Application Center Version 10.2 Fix Pack 14. | `bool` | `false` | no |
| <a name="input_enable_cos_integration"></a> [enable\_cos\_integration](#input\_enable\_cos\_integration) | Set to true to create an extra cos bucket to integrate with HPC cluster deployment. | `bool` | `false` | no |
| <a name="input_enable_fip"></a> [enable\_fip](#input\_enable\_fip) | The solution supports multiple ways to connect to your IBM Cloud HPC cluster for example, using a login node, or using VPN or direct connection. If connecting to the IBM Cloud HPC cluster using VPN or direct connection, set this value to false. | `bool` | `true` | no |
| <a name="input_enable_ldap"></a> [enable\_ldap](#input\_enable\_ldap) | Set this option to true to enable LDAP for IBM Cloud HPC, with the default value set to false. | `bool` | `false` | no |
| <a name="input_enable_vpc_flow_logs"></a> [enable\_vpc\_flow\_logs](#input\_enable\_vpc\_flow\_logs) | Flag to enable VPC flow logs. If true, a flow log collector will be created. | `bool` | `false` | no |
| <a name="input_hyperthreading_enabled"></a> [hyperthreading\_enabled](#input\_hyperthreading\_enabled) | Setting this to true will enable hyper-threading in the compute nodes of the cluster (default). Otherwise, hyper-threading will be disabled. | `bool` | `true` | no |
| <a name="input_ibmcloud_api_key"></a> [ibmcloud\_api\_key](#input\_ibmcloud\_api\_key) | IBM Cloud API key for the IBM Cloud account where the IBM Cloud HPC cluster needs to be deployed. For more information on how to create an API key, see [Managing user API keys](https://cloud.ibm.com/docs/account?topic=account-userapikey). | `string` | n/a | yes |
| <a name="input_key_management"></a> [key\_management](#input\_key\_management) | Setting this to key\_protect will enable customer managed encryption for boot volume and file share. If the key\_management is set as null, encryption will be always provider managed. | `string` | `"key_protect"` | no |
| <a name="input_kms_instance_name"></a> [kms\_instance\_name](#input\_kms\_instance\_name) | Name of the Key Protect instance associated with the Key Management Service. Note: kms\_instance\_name to be considered only if key\_management value is set to key\_protect. The name can be found under the details of the KMS, see [View key-protect ID](https://cloud.ibm.com/docs/key-protect?topic=key-protect-retrieve-instance-ID&interface=ui). | `string` | `null` | no |
| <a name="input_kms_key_name"></a> [kms\_key\_name](#input\_kms\_key\_name) | Provide the existing KMS encryption key name that you want to use for the IBM Cloud HPC cluster. Note: kms\_instance\_name to be considered only if key\_management value is set to key\_protect. (for example kms\_key\_name: my-encryption-key). | `string` | `null` | no |
| <a name="input_ldap_admin_password"></a> [ldap\_admin\_password](#input\_ldap\_admin\_password) | The LDAP administrative password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@\_+:) are required. It is important to avoid including the username in the password for enhanced security.[This value is ignored for an existing LDAP server]. | `string` | `""` | no |
| <a name="input_ldap_basedns"></a> [ldap\_basedns](#input\_ldap\_basedns) | The dns domain name is used for configuring the LDAP server. If an LDAP server is already in existence, ensure to provide the associated DNS domain name. | `string` | `"hpcaas.com"` | no |
| <a name="input_ldap_server"></a> [ldap\_server](#input\_ldap\_server) | Provide the IP address for the existing LDAP server. If no address is given, a new LDAP server will be created. | `string` | `"null"` | no |
| <a name="input_ldap_user_name"></a> [ldap\_user\_name](#input\_ldap\_user\_name) | Custom LDAP User for performing cluster operations. Note: Username should be between 4 to 32 characters, (any combination of lowercase and uppercase letters).[This value is ignored for an existing LDAP server] | `string` | `""` | no |
| <a name="input_ldap_user_password"></a> [ldap\_user\_password](#input\_ldap\_user\_password) | The LDAP user password should be 8 to 20 characters long, with a mix of at least three alphabetic characters, including one uppercase and one lowercase letter. It must also include two numerical digits and at least one special character from (~@\_+:) are required.It is important to avoid including the username in the password for enhanced security.[This value is ignored for an existing LDAP server]. | `string` | `""` | no |
| <a name="input_ldap_vsi_osimage_name"></a> [ldap\_vsi\_osimage\_name](#input\_ldap\_vsi\_osimage\_name) | Image name to be used for provisioning the LDAP instances. | `string` | `"ibm-ubuntu-22-04-3-minimal-amd64-1"` | no |
| <a name="input_ldap_vsi_profile"></a> [ldap\_vsi\_profile](#input\_ldap\_vsi\_profile) | Profile to be used for LDAP virtual server instance. | `string` | `"cx2-2x4"` | no |
| <a name="input_login_node_instance_type"></a> [login\_node\_instance\_type](#input\_login\_node\_instance\_type) | Specify the virtual server instance profile type to be used to create the login node for the IBM Cloud HPC cluster. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles). | `string` | `"bx2-2x8"` | no |
| <a name="input_login_subnet_id"></a> [login\_subnet\_id](#input\_login\_subnet\_id) | List of existing subnet ID under the VPC, where the login/Bastion server will be provisioned. One subnet id is required as input value for the creation of login node and bastion in the same zone as the management nodes are created. Note: Provide a different subnet id for login\_subnet\_id, do not overlap or provide the same subnet id that was already provided for cluster\_subnet\_ids. | `string` | `null` | no |
| <a name="input_management_image_name"></a> [management\_image\_name](#input\_management\_image\_name) | Name of the custom image that you want to use to create virtual server instances in your IBM Cloud account to deploy the IBM Cloud HPC cluster management nodes. By default, the solution uses a base image with additional software packages mentioned [here](https://cloud.ibm.com/docs/hpc-spectrum-LSF#create-custom-image). If you would like to include your application-specific binary files, follow the instructions in [ Planning for custom images ](https://cloud.ibm.com/docs/vpc?topic=vpc-planning-custom-images) to create your own custom image and use that to build the IBM Cloud HPC cluster through this offering. | `string` | `"hpcaas-lsf10-rhel88-v3"` | no |
| <a name="input_management_node_count"></a> [management\_node\_count](#input\_management\_node\_count) | Number of management nodes. This is the total number of management nodes. Enter a value between 1 and 10. | `number` | `3` | no |
| <a name="input_management_node_instance_type"></a> [management\_node\_instance\_type](#input\_management\_node\_instance\_type) | Specify the virtual server instance profile type to be used to create the management nodes for the IBM Cloud HPC cluster. For choices on profile types, see [Instance profiles](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles). | `string` | `"bx2-16x64"` | no |
| <a name="input_remote_allowed_ips"></a> [remote\_allowed\_ips](#input\_remote\_allowed\_ips) | Comma-separated list of IP addresses that can access the IBM Cloud HPC cluster instance through an SSH interface. For security purposes, provide the public IP addresses assigned to the devices that are authorized to establish SSH connections (for example, ["169.45.117.34"]). To fetch the IP address of the device, use [https://ipv4.icanhazip.com/](https://ipv4.icanhazip.com/). | `list(string)` | n/a | yes |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | Resource group name from your IBM Cloud account where the VPC resources should be deployed. Note. If the resource group value is set as null, automation creates two different RG with the name (workload-rg and service-rg). For additional information on resource groups, see [Managing resource groups](https://cloud.ibm.com/docs/account?topic=account-rgs). | `string` | `"Default"` | no |
| <a name="input_skip_iam_authorization_policy"></a> [skip\_iam\_authorization\_policy](#input\_skip\_iam\_authorization\_policy) | Set it to false if authorization policy is required for VPC to access COS. This can be set to true if authorization policy already exists. For more information on how to create authorization policy manually, see [creating authorization policies for VPC flow log](https://cloud.ibm.com/docs/vpc?topic=vpc-ordering-flow-log-collector&interface=ui#fl-before-you-begin-ui). | `string` | `false` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | Creates the address prefix for the new VPC, when the vpc\_name variable is empty. The VPC requires an address prefix for each subnet in two different zones. The subnets are created with the specified CIDR blocks, enabling support for two zones within the VPC. For more information, see [Setting IP ranges](https://cloud.ibm.com/docs/vpc?topic=vpc-vpc-addressing-plan-design). | `string` | `"10.241.0.0/18,10.241.64.0/18"` | no |
| <a name="input_vpc_cluster_login_private_subnets_cidr_blocks"></a> [vpc\_cluster\_login\_private\_subnets\_cidr\_blocks](#input\_vpc\_cluster\_login\_private\_subnets\_cidr\_blocks) | The CIDR block that's required for the creation of the login cluster private subnet. Modify the CIDR block if it conflicts with any on-premises CIDR blocks when using a hybrid environment. Provide only one CIDR block for the creation of the login subnet. Since login subnet is used only for the creation of login virtual server instances,  provide a CIDR range of /28. | `list(string)` | <pre>[<br>  "10.241.16.0/28"<br>]</pre> | no |
| <a name="input_vpc_cluster_private_subnets_cidr_blocks"></a> [vpc\_cluster\_private\_subnets\_cidr\_blocks](#input\_vpc\_cluster\_private\_subnets\_cidr\_blocks) | The CIDR block that's required for the creation of the compute cluster private subnet. Modify the CIDR block if it conflicts with any on-premises CIDR blocks when using a hybrid environment. Make sure to select a CIDR block size that will accommodate the maximum number of management and dynamic compute nodes that you expect to have in your cluster. Requires one CIDR block for each subnet in two different zones. For more information on CIDR block size selection, see [Choosing IP ranges for your VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-choosing-ip-ranges-for-your-vpc). | `list(string)` | <pre>[<br>  "10.241.0.0/20",<br>  "10.241.64.0/20"<br>]</pre> | no |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Name of an existing VPC in which the cluster resources will be deployed. If no value is given, then a new VPC will be provisioned for the cluster. [Learn more](https://cloud.ibm.com/docs/vpc) | `string` | `null` | no |
| <a name="input_vpn_enabled"></a> [vpn\_enabled](#input\_vpn\_enabled) | Set the value as true to deploy a VPN gateway for VPC in the cluster. | `bool` | `false` | no |
| <a name="input_zones"></a> [zones](#input\_zones) | IBM Cloud zone names within the selected region where the IBM Cloud HPC cluster should be deployed. Two zone names are required as input value and supported zones for eu-de are eu-de-2, eu-de-3 and for us-east us-east-1, us-east-3. The management nodes and file storage shares will be deployed to the first zone in the list. Compute nodes will be deployed across both first and second zones, where the first zone in the list will be considered as the most preferred zone for compute nodes deployment. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-a-vpc-in-a-different-region#get-zones-using-the-cli). | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application_center"></a> [application\_center](#output\_application\_center) | n/a |
| <a name="output_application_center_url"></a> [application\_center\_url](#output\_application\_center\_url) | n/a |
| <a name="output_image_entry_found"></a> [image\_entry\_found](#output\_image\_entry\_found) | n/a |
| <a name="output_region_name"></a> [region\_name](#output\_region\_name) | n/a |
| <a name="output_ssh_to_ldap_node"></a> [ssh\_to\_ldap\_node](#output\_ssh\_to\_ldap\_node) | n/a |
| <a name="output_ssh_to_login_node"></a> [ssh\_to\_login\_node](#output\_ssh\_to\_login\_node) | n/a |
| <a name="output_ssh_to_management_node"></a> [ssh\_to\_management\_node](#output\_ssh\_to\_management\_node) | SSH command to connect to HPC cluster |
| <a name="output_vpc_name"></a> [vpc\_name](#output\_vpc\_name) | n/a |
