# HPC Automation - LSF

## Overview

This repository contains automation tests for High-Performance Computing as a Service (HPCaaS-LSF) using the `ibmcloud-terratest-wrapper/testhelper` library and the Terratest framework in Golang. This guide provides instructions for setting up the environment, running tests, and troubleshooting issues.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Cloning the Repository](#cloning-the-repository)
3. [Setting Up the Go Project](#setting-up-the-go-project)
4. [Running the Tests](#running-the-tests)

   * [Passing Input Parameters](#passing-input-parameters)

     * [Updating `lsf_config.yml`](#updating-lsf_configyml)
     * [Command-Line Overrides](#command-line-overrides)
   * [Using Default Parameters](#using-default-parameters)
   * [Overriding Parameters](#overriding-parameters)
   * [Running Multiple Tests](#running-multiple-tests)
5. [Exporting API Key](#exporting-api-key)
6. [Analyzing Test Results](#analyzing-test-results)

   * [Reviewing Test Output](#reviewing-test-output)
   * [Viewing Test Output Logs](#viewing-test-output-logs)
7. [Troubleshooting](#troubleshooting)

   * [Common Issues](#common-issues)
8. [Project Structure](#project-structure)
9. [Utilities](#utilities)

   * [LSF Utilities](#lsf-utilities)
   * [LSF Cluster Test Utilities](#lsf-cluster-test-utilities)
   * [Test Validation Utilities](#test-validation-utilities)
   * [SSH Utilities](#ssh-utilities)
   * [Logger Utilities](#logger-utilities)
   * [Common Utilities](#common-utilities)
   * [Deploy Utilities](#deploy-utilities)
10. [Acknowledgments](#acknowledgments)

---

## Prerequisites

Ensure you have the following tools and utilities installed:

* **Go Programming Language**: [Install Go](https://golang.org/doc/install)
* **Git**: [Install Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
* **Terraform**: [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
* **IBM Cloud CLI**: [Install IBM Cloud CLI](https://cloud.ibm.com/docs/cli?topic=cli-install-ibmcloud-cli)
* **IBM Cloud Plugins**:

  ```sh
  ibmcloud plugin install cloud-object-storage
  ibmcloud plugin install vpc-infrastructure
  ibmcloud plugin install dns
  ibmcloud plugin install security-compliance
  ibmcloud plugin install key-protect -r "IBM Cloud"
  ```

---

## Cloning the Repository

Clone the repository to your local machine:

```sh
git clone https://github.ibm.com/workload-eng-services/HPCaaS.git
```

---

## Setting Up the Go Project

Navigate to the test directory:

```sh
cd HPCaaS/tests/
```

Install project dependencies using Go modules:

```sh
go mod tidy
```

Initialize Git Submodules:

```sh
git submodule update --init
```

Navigate to the test directory:

```sh
cd HPCaaS/tests
```

---

## Running the Tests

### Passing Input Parameters

#### For Solution LSF

##### Updating `lsf_config.yml`

You can update the `/tests/data/lsf_config.yml` file to provide input parameters. This file contains default values for various parameters used during testing. Modify the values as needed to suit your testing requirements.

---

### Command-Line Overrides

If you want to override the values in `lsf_config.yml`, you can pass the input parameters through the command line. For example:

```sh
export TF_VAR_ibmcloud_api_key=your_api_key  # pragma: allowlist secret
export TF_VAR_github_token=your_github_token
export LOG_FILE_NAME="filename.json"
SSH_KEYS=your_ssh_key ZONES=your_zone EXISTING_RESOURCE_GROUP=your_existing_resource_group SOLUTION=your_solution go test -v -timeout 900m -parallel 4 -run "TestRunBasic" | tee -a $LOG_FILE_NAME
```

Replace placeholders (e.g., `your_ssh_key`, `your_zone`, etc.) with actual values.

---

### Running a Specific Test

```sh
export TF_VAR_ibmcloud_api_key=your_api_key # pragma: allowlist secret
export TF_VAR_github_token=your_github_token
export LOG_FILE_NAME="filename.json"
SSH_KEYS=your_ssh_key go test -v -timeout=900m -parallel 10 -run="^TestRunBasic$" | tee -a $LOG_FILE_NAME
```

---

### Using Default Parameters

```sh
export TF_VAR_ibmcloud_api_key=your_api_key   # pragma: allowlist secret
export TF_VAR_github_token=your_github_token
export LOG_FILE_NAME="filename.json"
go test -v -timeout 900m -parallel 4 -run "TestRunBasic" | tee -a $LOG_FILE_NAME
```

---

### Overriding Parameters

Example:

```sh
LSF_VERSION=your_lsf_version \
SSH_KEYS=your_ssh_key \
ZONES=your_zone \
IMAGE_NAME=your_image_name \
DEFAULT_EXISTING_RESOURCE_GROUP=your_default_existing_resource_group \
NON_DEFAULT_EXISTING_RESOURCE_GROUP=your_non_default_existing_resource_group \
KMS_KEY_NAME=your_kms_key_name \
KEY_MANAGEMENT=enabled \
KMS_INSTANCE_NAME=your_kms_instance_name \
KMS_INSTANCE_ID=your_kms_instance_id \
ENABLE_HYPERTHREADING=trueOrFalse \
SSH_FILE_PATH=your_ssh_file_path \
REMOTE_ALLOWED_IPS=your_system_ip \
APP_CENTER_EXISTING_CERTIFICATE_INSTANCE=your_app_center_existing_certificate_instance \
go test -v -timeout=900m -parallel=4 -run "TestRunBasic" | tee -a $LOG_FILE_NAME
```

---

### Running Multiple Tests

```sh
export TF_VAR_ibmcloud_api_key=your_api_key     # pragma: allowlist secret
export TF_VAR_github_token=your_github_token
export LOG_FILE_NAME="filename.json"
go test -v -timeout 900m -parallel 10 -run="TestRunDefault|TestRunBasic|TestRunLDAP|TestRunAppCenter" | tee -a $LOG_FILE_NAME
```

---

### Specific Test Files

* `lsf_pr_test.go`: PR validation tests.
* `lsf_e2e_test.go`: Functional test coverage (P0, P1, P2).
* `lsf_negative_test.go`: Negative test validations.

---

## Exporting API Key

```sh
export TF_VAR_ibmcloud_api_key="your_api_key"  # pragma: allowlist secret
export LOG_FILE_NAME="your_log_file_name"
```

---

## Analyzing Test Results

### Reviewing Test Output

**Pass Example:**

```sh
--- PASS: TestRunHpcBasicExample (514.35s)
PASS
ok github.com/terraform-ibm-modules/terraform-ibmcloud-hpc 514.369s
```

**Fail Example:**

```sh
--- FAIL: TestRunHpcBasicExample (663.30s)
FAIL
exit status 1
FAIL github.com/terraform-ibm-modules/terraform-ibcloud-hpc 663.323s
```

---

### Viewing Test Output Logs

* **Console Output**: Immediate feedback.
* **Log Files**: Saved under `/tests/logs_output`, timestamped.

---

## Troubleshooting

### Common Issues

* **Missing Test Directories**
* **Invalid API/SSH Keys**
* **Zone Misconfiguration**
* **Network/Firewall Rules**
* **Insufficient Cloud Resources**
* **Terraform Init Errors**
* **Check `REMOTE_ALLOWED_IPS`**

### Debugging `TF_VAR_github_token`

```sh
echo $TF_VAR_github_token
export TF_VAR_github_token="your_github_token"
```

* Ensure the token includes proper GitHub permissions (`repo`, `workflow`, etc.)




---

## Project Structure

```
/root/HPCAAS/tests
│
├── data/                           # Cluster config files
│   ├── lsf_14_config.yml           # Input YAML for test setup
│   └── lsf_15_config.yml           # Input YAML for test setup
│
├── deployment/                     # Deployment-specific logic
│   └── lsf_deployment.go
│
├── logs_output/                    # Runtime or SSH logs
│   └── output.txt
│
├── lsf/                            # Core logic and cluster operations
│   ├── cluster_helpers.go
│   ├── cluster_utils.go
│   ├── cluster_validation.go
│   └── constants.go
│
├── utilities/                      # Shared utils across modules
│   ├── api_utils.go                # IBM Cloud API interaction helpers
│   ├── fileops.go                  # File read/write utilities
│   ├── helpers.go                  # Common general-purpose functions
│   ├── logging.go                  # Centralized logger
│   ├── report.go                   # HTML/JSON report generation
│   ├── resources.go                # Resource-specific helpers
│   └── ssh.go                      # SSH connection + command execution
│
├── lsf_tests/  
│   ├── lsf_e2e_test.go             # Full end-to-end test
│   ├── lsf_negative_test.go        # Negative test scenarios
│   ├── lsf_setup.go
│   ├── lsf_constants.go
│   ├── resource_exemptions.go          
│   └── README.md                   # Instructions for running tests
|
├── go.mod                          # Go module file
├── go.sum                          # Go module file
│── pr_test.go                  # PR-level minimal test

```

---

## Utilities

* `lsf/` - Helper functions for LSF validation.
* `lsf_tests/` - All test cases.
* `deployment/` - Provisioning and teardown logic.
* `utilities/`:

  * `ssh.go` - SSH logic
  * `logger.go` - JSON and plain log generation
  * `common.go` - Shared test utilities
  * `validation.go` - Functional/infra test logic
  * `deploy.go` - Cluster-level provisioning

### LSF Utilities: `cluster_utils.go`

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
- **LSFCheckClusterName**: Check the cluster Name.
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

### LSF Cluster Test Utilities: `cluster_helpers.go`

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
