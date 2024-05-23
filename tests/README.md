
# IBM Cloud HPC - Running Tests with Terratest

## Prerequisites

Ensure the following tools and utilities are installed and configured on your system:

- **Go Programming Language**
- **Git**
- **Terraform**
- **IBM Cloud Plugins**:
  ```sh
  ibmcloud plugin install cloud-object-storage
  ibmcloud plugin install key-protect -r "IBM Cloud"
  ```
- **Initialize Git Submodules**:
  ```sh
  git submodule update --init
  ```

## Clone the Repository

Clone the repository containing your Go project:

```sh
git clone https://github.ibm.com/workload-eng-services/HPCaaS.git
```

## Set up Your Go Project

1. Navigate to the project directory:
   ```sh
   cd HPCaaS/tests
   ```

2. Install project dependencies using Go modules:
   ```sh
   go mod tidy
   ```

## Running the Tests

### Option 1: Use Default Parameters from YAML File

You can run the tests using the default parameter values specified in the YAML file:

```sh
go test -v -timeout 900m -parallel 4 -run "TestRunBasic" | tee test_output.log
```

### Option 2: Override Parameters

If you want to override the default values, you can pass only the parameters you need to change, or you can override all the values based on your requirements. To do this, execute the following command with your desired parameter values:

```sh
SSH_KEY=your_ssh_key ZONE=your_zone RESOURCE_GROUP=your_resource_group RESERVATION_ID=your_reservation_id KMS_INSTANCE_ID=kms_instance_id KMS_KEY_NAME=kms_key_name IMAGE_NAME=image_name CLUSTER=your_cluster_id DEFAULT_RESOURCE_GROUP=default_resource_group NON_DEFAULT_RESOURCE_GROUP=non_default_resource_group LOGIN_NODE_INSTANCE_TYPE=login_node_instance_type MANAGEMENT_IMAGE_NAME=management_image_name COMPUTE_IMAGE_NAME=compute_image_name MANAGEMENT_NODE_INSTANCE_TYPE=management_node_instance_type MANAGEMENT_NODE_COUNT=management_node_count ENABLE_VPC_FLOW_LOGS=enable_vpc_flow_logs KEY_MANAGEMENT=key_management KMS_INSTANCE_NAME=kms_instance_name HYPERTHREADING_ENABLED=hyperthreading_enabled US_EAST_ZONE=us_east_zone US_EAST_RESERVATION_ID=us_east_reservation_id US_EAST_CLUSTER_ID=us_east_cluster_id US_SOUTH_ZONE=us_south_zone US_SOUTH_RESERVATION_ID=us_south_reservation_id US_SOUTH_CLUSTER_ID=us_south_cluster_idEU_GB_ZONE=eu_gb_zone EU_GB_RESERVATION_ID=eu_gb_reservation_id EU_GB_CLUSTER_ID=eu_gb_cluster_id SSH_FILE_PATH=ssh_file_path go test -v -timeout 900m -parallel 4 -run "TestRunBasic" | tee test_output.log
```

Replace placeholders (e.g., `your_ssh_key`, `your_zone`) with actual values.

### Running Multiple Tests Simultaneously

To run multiple tests at the same time:

```sh
go test -v -timeout 900m -parallel 10 -run="TestRunDefault|TestRunBasic|TestRunLDAP|TestRunAppCenter" | tee test_output.log
```

### Export API Key

Before running tests, export the IBM Cloud API key:

```sh
export TF_VAR_ibmcloud_api_key=your_api_key //pragma: allowlist secret
```
 
Replace `your_api_key` with your actual API key. //pragma: allowlist secret

## Analyzing Test Results

### Review Test Output

- **Passing Test Example**:
  ```sh
  --- PASS: TestRunHpcBasicExample (514.35s)
  PASS
  ok github.com/terraform-ibm-modules/terraform-ibmcloud-hpc 514.369s
  ```

- **Failing Test Example**:
  ```sh
  --- FAIL: TestRunHpcBasicExample (663.30s)
  FAIL
  exit status 1
  FAIL github.com/terraform-ibm-modules/terraform-ibmcloud-hpc 663.323s
  ```

### Test Output Logs

- **Console Output**: Check the console for detailed test results.
- **Log Files**: Review `test_output.log` and custom logs in the `/tests/test_output` folder with a timestamp for detailed analysis and troubleshooting. For example, a log file might be named `log_20XX-MM-DD_HH-MM-SS.log`.

## Troubleshooting

### Common Issues

- **Missing Test Directories**: Verify the project structure and required files.
- **Invalid API Key**: Ensure `TF_VAR_ibmcloud_api_key` is correct.
- **Invalid SSH Key**: Check the `SSH_KEY` value.
- **Invalid Zone**: Ensure `ZONE` is set correctly.
- **Remote IP Configuration**: Customize `REMOTE_ALLOWED_IPS` if needed.
- **Terraform Initialization**: Ensure Terraform modules and plugins are up-to-date.
- **Test Output Logs**: Review logs for errors and failure messages.

For additional assistance, contact the project maintainers.
