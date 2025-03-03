# IBM Spectrum LSF
Repository for the IBM Spectrum LSF project with IBM Spectrum schedulers

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
# Paste your API key and other mandatory parameters value for IBM Spectrum LSF cluster
# Login to the IBM Cloud CLI
$ ibmcloud catalog install --vl <version-locator-value> --override-values values.json

Note: You can retrieve the <version-locator-value> by accessing the CLI section within the Deployment options of the IBM Spectrum LSF tile.

It bears resemblance to something along these lines:
$ ibmcloud catalog install --vl 1082e7d2-5e2f-0a11-a3bc-f88a8e1931fc.c7645085-5f49-4d5f-8786-45ac376e60fe-global --override-values values.json
Attempting install of IBM Spectrum LSF version x.x.x...
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
# Paste your API key and other mandatory parameters value for IBM Spectrum LSF cluster
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
 2025/02/18 15:00:57 Terraform apply | Apply complete! Resources: 123 added, 0 changed, 0 destroyed.
 2025/02/18 15:00:57 Terraform apply | 
 2025/02/18 15:00:57 Terraform apply | Outputs:
 2025/02/18 15:00:57 Terraform apply | 
 2025/02/18 15:00:57 Terraform apply | image_entry_found = "true --  - hpc-lsf10-rhel810-v1"
 2025/02/18 15:00:57 Terraform apply | region_name = "us-east"
 2025/02/18 15:00:57 Terraform apply | remote_allowed_cidr = [
 2025/02/18 15:00:57 Terraform apply |   "xxxxxxxx",
 2025/02/18 15:00:57 Terraform apply | ]
 2025/02/18 15:00:57 Terraform apply | ssh_to_login_node = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/xxxhiddenxxx -J ubuntu@xxxxxxxxx lsfadmin@xxxxxxxx"
 2025/02/18 15:00:57 Terraform apply | ssh_to_management_node_1 = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/xxxhiddenxxx -J ubuntu@xxxxxxxxxxx lsfadmin@xxxxxxx"
 2025/02/18 15:00:57 Terraform apply | vpc_name = "hpc-lsf-hpc-vpc --  - r014-7119e3ed-a3b9-4256-9418-f93f94527c1d"
 2025/02/18 15:00:57 Terraform apply | worker_node_min_count = 0
 2025/02/18 15:00:57 Command finished successfully.
OK
```

### Accessing the deployed environment:

* Connect to an LSF login node through SSH by using the `ssh_to_login_node` command from the Schematics log output.
```
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@<floating_IP_address> lsfadmin@<login_node_IP_address>
```
* where `floating_IP_address` is the floating IP address for the bastion node and `login_node_IP_address` is the IP address for the login node.

### Steps to access the Application Center GUI/Dashboard:

* Open a new command line terminal.
* Connect to an LSF management node through SSH by using the `application_center_tunnel` command from the Schematics log output.

```
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -L 8443:localhost:8443 -L 6080:localhost:6080 -J ubuntu@><floating_IP_address> lsfadmin@<management_node_IP_address>
```
* where `floating_IP_address` is the floating IP address for the bastion node and `management_node_IP_address` is the IP address for the management node.

* Open a browser on the local machine, and run https://localhost:8443

* To access the Application Center GUI, enter the password you configured when you created your workspace and the default user as "lsfadmin".

* If LDAP is enabled, you can access the LSF Application Center using the LDAP username and password that you configured during IBM Spectrum LSF cluster deployment or using an existing LDAP username and password.

* If IBM Spectrum LSF Application Center GUI is installed in High Availability. The `application_center_tunnel` command is a bit different. Then read also `application_center_url_note` line.
```
"ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -L 8443:pac.<domain_name>:8443 -L 6080:pac.<domain_name>:6080 -J ubuntu@<floating_IP_address> lsfadmin@<login_vsi_IP_address>"
application_center_url = "https://pac.<domain_name>:8443"
```

### Steps to validate the OpenLDAP:
* Connect to your OpenLDAP server through SSH by using the `ssh_to_ldap_node` command from the Schematics log output.

```
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=5 -o ServerAliveCountMax=1 -J ubuntu@<floatingg_IP_address> ubuntu@<LDAP_server_IP>
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
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J ubuntu@<floating_IP_address> lsfadmin@<management_node_IP_address>
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
[lsfuser05@hpccluster-mgmt-1 lsfadmin]$ bsub -n 8 sleep 100
Job <1> is submitted to default queue <normal>.
```

### Cleaning up the deployed environment:

If you no longer need your deployed IBM Spectrum LSF cluster, you can clean it up from your environment. The process is threefold: ensure that the cluster is free of running jobs or working compute nodes, destroy all the associated VPC resources and remove them from your IBM Cloud account, and remove the project from the IBM Cloud console.

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

No requirements.

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

No inputs.

## Outputs

No outputs.
