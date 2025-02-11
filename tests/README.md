

# HPC Automation

## Overview

This repository contains automation tests for High-Performance Computing as a Service (HPCaaS) using the `ibmcloud-terratest-wrapper/testhelper` library and the Terratest framework in Golang. This guide provides instructions for setting up the environment, running tests, and troubleshooting issues.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Cloning the Repository](#cloning-the-repository)
3. [Setting Up the Go Project](#setting-up-the-go-project)
4. [Running the Tests](#running-the-tests)
   - [Passing Input Parameters](#passing-input-parameters)
     - [Updating `test_config.yml`](#updating-test_configyml)
     - [Command-Line Overrides](#command-line-overrides)
   - [Using Default Parameters](#using-default-parameters)
   - [Overriding Parameters](#overriding-parameters)
   - [Running Multiple Tests](#running-multiple-tests)
5. [Exporting API Key](#exporting-api-key)
6. [Analyzing Test Results](#analyzing-test-results)
   - [Reviewing Test Output](#reviewing-test-output)
   - [Viewing Test Output Logs](#viewing-test-output-logs)
7. [Troubleshooting](#troubleshooting)
   - [Common Issues](#common-issues)
8. [Project Structure](#project-structure)
9. [Utilities](#utilities)
   - [LSF Utilities](#lsf-utilities)
   - [LSF Cluster Test Utilities](#lsf-cluster-test-utilities)
   - [Test Validation Utilities](#test-validation-utilities)
   - [SSH Utilities](#ssh-utilities)
   - [Logger Utilities](#logger-utilities)
   - [Common Utilities](#common-utilities)
   - [Deploy Utilities](#deploy-utilities)
10. [Acknowledgments](#acknowledgments)

## Prerequisites

Ensure you have the following tools and utilities installed:

- **Go Programming Language**: [Install Go](https://golang.org/doc/install)
- **Git**: [Install Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- **Terraform**: [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- **IBM Cloud CLI**: [Install IBM Cloud CLI](https://cloud.ibm.com/docs/cli?topic=cli-install-ibmcloud-cli)
- **IBM Cloud Plugins**:
  ```sh
  ibmcloud plugin install cloud-object-storage
  ibmcloud plugin install vpc-infrastructure
  ibmcloud plugin install dns
  ibmcloud plugin install security-compliance
  ibmcloud plugin install key-protect -r "IBM Cloud"
  ```


## Cloning the Repository

Clone the repository to your local machine:
```sh
git clone https://github.ibm.com/workload-eng-services/HPCaaS.git
```

## Setting Up the Go Project

Navigate to the project directory:
```sh
cd HPCaaS/tests
```

Install project dependencies using Go modules:
```sh
go mod tidy
```
Initialize Git Submodules:
  ```sh
  git submodule update --init
  ```


# Running the Tests

## Passing Input Parameters

### For Solution LSF

#### Updating `lsf_config.yml`

You can update the `lsf_config.yml` file to provide input parameters. This file contains default values for various parameters used during testing. Modify the values as needed to suit your testing requirements.

### For Solution HPC

#### Updating `hpc_config.yml`

You can update the `hpc_config.yml` file to provide input parameters. This file contains default values for various parameters used during testing. Modify the values as needed to suit your testing requirements.

## Command-Line Overrides

If you want to override the values in `lsf_config.yml` or `hpc_config.yml`, you can pass the input parameters through the command line. For example:

```sh
SSH_KEY=your_ssh_key ZONE=your_zone RESOURCE_GROUP=your_resource_group SOLUTION=your_solution go test -v -timeout 900m -parallel 4 -run "TestRunBasic" | tee -a $LOG_FILE_NAME
```

Replace placeholders (e.g., `your_ssh_key`, `your_zone`, etc.) with actual values.

## Running a Specific Test

To run a specific test, use the `-run` flag with the test name pattern. For example:

```sh
SOLUTION=your_solution  go test -v -timeout=900m -parallel 10 -run="^TestRunBasic$" | tee -a $LOG_FILE_NAME
```

This will run only the `TestRunBasic` test.

## Using Default Parameters

If you prefer to run tests with the default parameter values from the `lsf_config.yml` file, you can simply run:

```sh
SOLUTION=your_solution  go test -v -timeout 900m -parallel 4 -run "TestRunBasic" | tee -a $LOG_FILE_NAME
```


### Overriding Parameters

To override default values, pass the required parameters when executing the command. Below are examples for **HPC** and **LSF** solutions:

#### Example for HPC:
```sh
SOLUTION=hpc SSH_KEY=your_ssh_key ZONE=your_zone RESOURCE_GROUP=your_resource_group RESERVATION_ID=your_reservation_id KMS_INSTANCE_ID=your_kms_instance_id KMS_KEY_NAME=your_kms_key_name IMAGE_NAME=your_image_name CLUSTER=your_cluster_id DEFAULT_RESOURCE_GROUP=your_default_resource_group NON_DEFAULT_RESOURCE_GROUP=your_non_default_resource_group LOGIN_NODE_INSTANCE_TYPE=your_login_node_instance_type MANAGEMENT_IMAGE_NAME=your_management_image_name COMPUTE_IMAGE_NAME=your_compute_image_name MANAGEMENT_NODE_INSTANCE_TYPE=your_management_node_instance_type MANAGEMENT_NODE_COUNT=your_management_node_count ENABLE_VPC_FLOW_LOGS=true KEY_MANAGEMENT=enabled KMS_INSTANCE_NAME=your_kms_instance_name HYPERTHREADING_ENABLED=true SSH_FILE_PATH=your_ssh_file_path EXISTING_CERTIFICATE_INSTANCE=existing_certificate_instance go test -v -timeout=900m -parallel=4 -run "TestRunBasic"| tee -a $LOG_FILE_NAME
```

#### Example for LSF:
```sh
SOLUTION=lsf SSH_KEY=your_ssh_key ZONE=your_zone RESOURCE_GROUP=your_resource_group IBM_CUSTOMER_NUMBER=your_customer_number WORKER_NODE_MAX_COUNT=your_worker_node_max_count WORKER_NODE_INSTANCE_TYPE=your_worker_node_instance_type KMS_INSTANCE_ID=your_kms_instance_id KMS_KEY_NAME=your_kms_key_name IMAGE_NAME=your_image_name CLUSTER=your_cluster_id DEFAULT_RESOURCE_GROUP=your_default_resource_group NON_DEFAULT_RESOURCE_GROUP=your_non_default_resource_group LOGIN_NODE_INSTANCE_TYPE=your_login_node_instance_type MANAGEMENT_IMAGE_NAME=your_management_image_name COMPUTE_IMAGE_NAME=your_compute_image_name MANAGEMENT_NODE_INSTANCE_TYPE=your_management_node_instance_type MANAGEMENT_NODE_COUNT=your_management_node_count ENABLE_VPC_FLOW_LOGS=true KEY_MANAGEMENT=enabled KMS_INSTANCE_NAME=your_kms_instance_name HYPERTHREADING_ENABLED=true SSH_FILE_PATH=your_ssh_file_path EXISTING_CERTIFICATE_INSTANCE=existing_certificate_instance go test -v -timeout=900m -parallel=4 -run "TestRunBasic" | tee -a $LOG_FILE_NAME
```

### Notes:
- Replace placeholders (e.g., `your_ssh_key`, `your_zone`, etc.) with the actual values applicable to your setup.
- Ensure that all required parameters are included for the respective solution type (`HPC` or `LSF`).
- Parameters like `ENABLE_VPC_FLOW_LOGS` and `HYPERTHREADING_ENABLED` can be set as `true` or `false` based on your requirement.
- The parameter EXISTING_CERTIFICATE_INSTANCE should be assigned a value only when running the PAC HA test case.

### Running Multiple Tests

Execute multiple tests simultaneously:
```sh
go test -v -timeout 900m -parallel 10 -run="TestRunDefault|TestRunBasic|TestRunLDAP|TestRunAppCenter" | tee -a $LOG_FILE_NAME
```

### Specific Test Files

- `pr_test.go`: Contains tests that are run for any Pull Request (PR) raised. It ensures that changes proposed in a PR do not break existing functionality.
- `other_test.go`: Includes all P0, P1, and P2 test cases, covering all functional testing. It ensures comprehensive testing of all core functionalities.

## Exporting API Key


# Before running tests, export your IBM Cloud API key and log file name as environment variables.
export TF_VAR_ibmcloud_api_key="your_api_key"  # Replace 'your_api_key' with your actual IBM Cloud API key  # pragma: allowlist secret
export LOG_FILE_NAME="your_log_file_name"      # Replace 'your_log_file_name' with the desired log file name


## Analyzing Test Results

### Reviewing Test Output

Passing Test Example:
```sh
--- PASS: TestRunHpcBasicExample (514.35s)
PASS
ok github.com/terraform-ibm-modules/terraform-ibmcloud-hpc 514.369s
```

Failing Test Example:
```sh
--- FAIL: TestRunHpcBasicExample (663.30s)
FAIL
exit status 1
FAIL github.com/terraform-ibm-modules/terraform-ibcloud-hpc 663.323s
```

### Viewing Test Output Logs

- **Console Output**: Check the console for immediate test results.
- **Log Files**: Detailed logs are saved in `test_output.log` and custom logs in the `/tests/logs_output` folder. Logs are timestamped for easier tracking (e.g., `log_20XX-MM-DD_HH-MM-SS.log`).

## Troubleshooting

### Common Issues

- **Missing Test Directories**: Ensure the project directory structure is correct and that the required directories for your tests are present.
- **Invalid API Key**: Verify that the `TF_VAR_ibmcloud_api_key` environment variable is set correctly.Double-check the key format and permissions. # pragma: allowlist secret
- **Invalid Solution Type**: Ensure that the `SOLUTION` environment variable is correctly defined. If it is misconfigured, tests may not run as expected.
- **Invalid SSH Key**: Confirm that the `SSH_KEY` environment variable is set properly and points to the correct SSH key file used for authentication.
- **Invalid Zone**: Check that the `ZONE` environment variable corresponds to a valid IBM Cloud zone where your resources are located.
- **Remote IP Configuration**: Ensure the `REMOTE_ALLOWED_IPS` environment variable is set to allow connections from the appropriate IP addresses. Update this if necessary.
- **Terraform Initialization**: Make sure Terraform modules and plugins are up-to-date by running `terraform init`. If any modules fail to load, investigate the error messages and ensure correct configuration.
- **Test Output Logs**: Inspect the test output logs carefully for errors and failure messages. Logs often provide useful hints on what went wrong during the test execution.
- **Resource Limitations**: Ensure there are enough resources (e.g., compute power, storage) available in the cloud environment for your tests to run successfully.
- **Network Configuration**: Double-check that your network configuration (e.g., firewall settings, security groups) allows necessary traffic for the tests.

For additional help, contact the project maintainers.

## Project Structure

```
/root/HPCAAS/tests
├── README.md
├── utilities
│   ├── deployment.go           # Deployment-related utility functions
│   ├── fileops.go              # File operations utility functions
│   ├── helpers.go              # General helper functions
│   ├── logging.go              # Logging utility functions
│   ├── resources.go            # Resource management utility functions
│   └── ssh.go                  # SSH utility functions
├── constants.go                # Project-wide constants
├── go.mod                       # Go module definition
├── go.sum                       # Go module checksum
├── lsf
│   ├── cluster_helpers.go      # Helper functions for cluster testing
│   ├── cluster_utils.go        # General utilities for cluster operations
│   ├── cluster_validation.go   # Validation logic for cluster tests
│   └── constants.go            # Constants specific to LSF
├── other_tests.go              # Additional test cases
├── pr_tests.go                 # Pull request-related tests
├── config.yml                  # Configuration file
└── logs                        # Directory for log files

```

## Utilities

### LSF Utilities: `lsf_cluster_utils.go`

- **CheckLSFVersion**: Verify the LSF version.
- **LSFCheckSSHKeyForComputeNodes**: Check SSH key for compute nodes.
- **LSFCheckSSHKeyForComputeNode**: Check SSH key for a specific compute node.
- **LSFCheckSSHKeyForManagementNodes**: Check SSH key for management nodes.
- **LSFCheckSSHKeyForManagementNode**: Check SSH key for a specific management node.
- **LSFCheckHyperthreading**: Verify hyperthreading configuration.
- **LSFDaemonsStatus**: Check the status of LSF daemons.
- **LSFGETDynamicComputeNodeIPs**: Retrieve IPs of dynamic compute nodes.
- **HPCCheckFileMount**: Verify file mount configuration.
- **LSFAPPCenterConfiguration**: Check APPCenter configuration.
- **LSFWaitForDynamicNodeDisappearance**: Wait for dynamic nodes to disappear.
- **LSFExtractJobID**: Extract job ID from LSF.
- **LSFRunJobs**: Run jobs on LSF.
- **LSFCheckBhostsResponse**: Check the response from `bhosts`.
- **LSFRebootInstance**: Reboot an LSF instance.
- **LSFCheckIntelOneMpiOnComputeNodes**: Check Intel MPI installation on compute nodes.
- **LSFControlBctrld**: Control `bctrld` service.
- **LSFRestartDaemons**: Restart LSF daemons.
- **LSFCheckManagementNodeCount**: Verify the count of management nodes.
- **HPCCheckContractID**: Check the contract ID for HPC.
- **LSFCheckMasterName**: Verify the master node name.
- **LSFCheckClusterID**: Check the cluster ID.
- **LSFIPRouteCheck**: Verify IP routing in LSF.
- **LSFMTUCheck**: Check the MTU settings.
- **IsDynamicNodeAvailable**: Check if a dynamic node is available.
- **verifyDirectories**: Verify the existence of directories.
- **VerifyTerraformOutputs**: Validate Terraform outputs.
- **LSFCheckSSHConnectivityToNodesFromLogin**: Verify SSH connectivity from the login node.
- **HPCCheckNoVNC**: Check NoVNC configuration.
- **GetJobCommand**: Get the command to run a job.
- **ValidateEncryption**: Validate file encryption.
- **ValidateRequiredEnvironmentVariables**: Check required environment variables.
- **LSFRunJobsAsLDAPUser**: Run jobs as an LDAP user.
- **HPCCheckFileMountAsLDAPUser**: Check file mount as an LDAP user.
- **verifyDirectoriesAsLdapUser**: Verify directories as an LDAP user.
- **VerifyLSFCommands**: Verify LSF commands.
- **VerifyLDAPConfig**: Check LDAP configuration.
- **VerifyLDAPServerConfig**: Validate LDAP server configuration.
- **runSSHCommandAndGetPaths**: Run an SSH command and retrieve file paths.
- **GetOSNameOfNode**: Get the OS name of a node.
- **verifyPTRRecords**: Verify PTR records.
- **CreateServiceInstanceAndReturnGUID**: Create a service instance and return its GUID.
- **DeleteServiceInstance**: Delete a service instance.
- **CreateKey**: Create a key.
- **LSFDNSCheck**: Verify LSF DNS settings.
- **HPCAddNewLDAPUser**: Add a new LDAP user.
- **VerifyLSFCommandsAsLDAPUser**: Verify LSF commands as an LDAP user.
- **VerifyCosServiceInstance**: Validate COS service instance.
- **HPCGenerateFilePathMap**: Generate a file path map.
- **ValidateFlowLogs**: Validate flow logs configuration.

### LSF Cluster Test Utilities: `lsf_cluster_test_utils.go`

- **VerifyManagementNodeConfig**: Verify configurations for management nodes.
- **VerifySSHKey**: Check if the SSH key is set correctly.
- **FailoverAndFailback**: Handle failover and failback processes.
- **RestartLsfDaemon**: Restart the LSF daemon.
- **RebootInstance**: Reboot an instance.
- **VerifyComputeNodeConfig**: Verify configurations for compute nodes.
- **VerifyLoginNodeConfig**: Verify configurations for login nodes.
- **VerifySSHConnectivityToNodesFromLogin**: Check SSH connectivity from the login node to other nodes.
- **VerifyTestTerraformOutputs**: Validate Terraform outputs for testing.
- **VerifyNoVNCConfig**: Verify NoVNC configurations.
- **VerifyAPPCenterConfig**: Check APPCenter configurations.
- **VerifyFileShareEncryption**: Validate file share encryption.
- **VerifyJobs**: Verify job statuses and configurations.
- **VerifyManagementNodeLDAPConfig**: Verify LDAP configurations for management nodes.
- **VerifyLoginNodeLDAPConfig**: Verify LDAP configurations for login nodes.
- **VerifyComputeNodeLDAPConfig**: Verify LDAP configurations for compute nodes.
- **CheckLDAPServerStatus**: Check the status of the LDAP server.
- **VerifyPTRRecordsForManagementAndLoginNodes**: Verify PTR records for management and login nodes.
- **CreateServiceInstanceAndKmsKey**: Create a service instance and KMS key.
- **DeleteServiceInstanceAndAssociatedKeys**: Delete a service instance and its associated keys.
- **VerifyCreateNewLdapUserAndManagementNodeLDAPConfig**: Verify the creation of a new LDAP user and management node LDAP configuration.
- **ValidateCosServiceInstanceAndVpcFlowLogs**: Validate COS service instance and VPC flow logs.
- **VerifyLSFDNS**: Check LSF DNS settings.

### Test Validation Utilities: `lsf_cluster_test_validation.go`

- **ValidateClusterConfigurationWithAPPCenter**: Validate cluster configuration with APPCenter.
- **ValidateClusterConfiguration**: Validate overall cluster configuration.
- **ValidateBasicClusterConfiguration**: Check basic cluster settings.
- **ValidateLDAPClusterConfiguration**: Verify LDAP configurations in the cluster.
- **ValidatePACANDLDAPClusterConfiguration**: Validate PAC and LDAP configurations.
- **ValidateClusterConfigurationWithAPPCenterForExistingEnv**: Validate cluster setup with APPCenter for an existing environment.
- **ValidateBasicClusterConfigurationWithVPCFlowLogsAndCos**: Check basic cluster configuration with VPC flow logs and COS.
- **ValidateClusterConfigurationWithMultipleKeys**: Validate cluster configuration with multiple keys.
- **ValidateExistingLDAPClusterConfig**: Check configurations for existing LDAP clusters.

### SSH Utilities

- **ConnectToHost**: Connect to a host via SSH.
- **ConnectToHostE**: Connect to a host via SSH with error handling.
- **ConnectToHostsWithMultipleUsers**: Connect to multiple hosts with different users.

### Logger Utilities

- **NewAggregatedLogger**: Create a custom logger with aggregated log levels.
- **getLogArgs**: Retrieve log arguments.

### Common Utilities

- **GetValueFromIniFile**: Retrieve values from an INI file.
- **ToCreateFile**: Create a file.
- **IsFileExist**: Check if a file exists.
- **IsPathExist**: Check if a path exists.
- **GetDirList**: Get a list of directories.
- **GetDirectoryFileList**: Get a list of files in a directory.
- **ToDeleteFile**: Delete a file.
- **ToCreateFileWithContent**: Create a file with specified content.
- **ReadRemoteFileContents**: Read contents from a remote file.
- **VerifyDataContains**: Verify if data contains specific values.
- **CountStringOccurrences**: Count occurrences of a string.
- **SplitString**: Split a string into substrings.
- **StringToInt**: Convert a string to an integer.
- **RemoveNilValues**: Remove nil values from a list.
- **LogVerificationResult**: Log the results of verification.
- **ParsePropertyValue**: Parse a property value.
- **FindImageNamesByCriteria**: Find image names based on criteria.
- **LoginIntoIBMCloudUsingCLI**: Log in to IBM Cloud using CLI.
- **CreateVPC**: Create a VPC.
- **IsVPCExist**: Check if a VPC exists.
- **GetRegion**: Get the region information.
- **SplitAndTrim**: Split and trim a string.
- **RemoveKeys**: Remove keys from a map.
- **GetBastionServerIP**: Get the IP address of the bastion server.
- **GetManagementNodeIPs**: Get IP addresses of management nodes.
- **GetLoginNodeIP**: Get the IP address of the login node.
- **GetLdapServerIP**: Get the IP address of the LDAP server.
- **GetServerIPs**: Get IP addresses of servers.
- **GetServerIPsWithLDAP**: Get IP addresses of servers with LDAP.
- **GenerateTimestampedClusterPrefix**: Generate a cluster prefix with a timestamp.
- **GetPublicIP**: Get the public IP address.
- **GetOrDefault**: Retrieve a value or default if not present.
- **GenerateRandomString**: Generate a random string.
- **GetSecretsManagerKey**: Retrieve a key from the secrets manager.
- **GetValueForKey**: Get a value for a specified key.
- **GetSubnetIds**: Get IDs of subnets.
- **GetDnsCustomResolverIds**: Get IDs of DNS custom resolvers.
- **ParseConfig**: Parse configuration files.
- **GetClusterSecurityID**: Get the security ID of the cluster.
- **UpdateSecurityGroupRules**: Update security group rules.
- **GetCustomResolverID**: Get the ID of the custom resolver.
- **RetrieveAndUpdateSecurityGroup**: Retrieve and update security group settings.
- **GetLdapIP**: Get the IP address of the LDAP server.
- **GetBastionIP**: Get the IP address of the bastion server.

### Deploy Utilities

- **GetConfigFromYAML**: Retrieve configuration from a YAML file.
- **SetEnvFromConfig**: Set environment variables from a configuration file.

## Acknowledgments

- [Terratest](https://terratest.gruntwork.io/)
- [ibmcloud-terratest-wrapper](https://github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper)
