package tests

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
	"testing"

	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
)

// Prerequisite: Ensure that you have logged into IBM Cloud using the LoginIntoIBMCloudUsingCLI function before calling this function
// CreateVPC creates a new Virtual Private Cloud (VPC) in IBM Cloud with the specified VPC name.
func CreateVPC(vpcName string) error {
	existingVPC, err := IsVPCExist(vpcName)
	if err != nil {
		return err
	}
	if !existingVPC {
		cmd := exec.Command("ibmcloud", "is", "vpc-create", vpcName)
		if output, err := cmd.CombinedOutput(); err != nil {
			return fmt.Errorf("VPC creation failed: %v\nCommand output: %s", err, string(output))
		}
		fmt.Printf("VPC %s created successfully\n", vpcName)
	} else {
		fmt.Println("An existing VPC is available")
	}
	return nil
}

// Prerequisite: Ensure that you have logged into IBM Cloud using the LoginIntoIBMCloudUsingCLI function before calling this function
// IsVPCExist checks if a VPC with the given name exists.
func IsVPCExist(vpcName string) (bool, error) {
	cmd := exec.Command("ibmcloud", "is", "vpcs", "--output", "json")
	output, err := cmd.Output()
	if err != nil {
		return false, fmt.Errorf("failed to list VPCs: %w", err)
	}

	return bytes.Contains(output, []byte(vpcName)), nil
}

// GetBastionServerIP retrieves the IP address from the BastionServer section in the specified INI file.
func GetBastionServerIPFromIni(t *testing.T, filePath string, logger *AggregatedLogger) (string, error) {
	value, err := GetValueFromIniFile(filePath+"/bastion.ini", "BastionServer")
	if err != nil {
		return "", fmt.Errorf("failed to get value from bastion.ini: %w", err)
	}
	logger.Info(t, fmt.Sprintf("Bastion Server IP: %s", value[1]))
	return value[1], nil
}

// GetManagementNodeIPs retrieves the IP addresses from the HPCAASCluster section in the specified INI file.
func GetManagementNodeIPsFromIni(t *testing.T, filePath string, logger *AggregatedLogger) ([]string, error) {
	value, err := GetValueFromIniFile(filePath+"/compute.ini", "HPCAASCluster")
	if err != nil {
		return nil, fmt.Errorf("failed to get value from compute.ini: %w", err)
	}
	logger.Info(t, fmt.Sprintf("Management Node IPs List: %q", value[1:]))
	return value[1:], nil
}

// GetLoginNodeIP retrieves the IP address from the LoginServer section in the specified login INI file.
func GetLoginNodeIPFromIni(t *testing.T, filePath string, logger *AggregatedLogger) (string, error) {
	value, err := GetValueFromIniFile(filePath+"/login.ini", "LoginServer")
	if err != nil {
		return "", fmt.Errorf("failed to get value from login.ini: %w", err)
	}
	logger.Info(t, fmt.Sprintf("Login Server IP: %s", value[1]))
	return value[1], nil
}

// GetLdapServerIP retrieves the IP address from the LdapServer section in the specified login INI file.
func GetLdapServerIPFromIni(t *testing.T, filePath string, logger *AggregatedLogger) (string, error) {
	value, err := GetValueFromIniFile(filePath+"/ldap.ini", "LDAPServer")
	if err != nil {
		return "", fmt.Errorf("failed to get value from ldap.ini: %w", err)
	}
	logger.Info(t, fmt.Sprintf("Ldap Server IP: %s", value[1]))
	return value[1], nil
}

// GetWorkerNodeIPsFromIni retrieves the IP address from the WorkerServer section in the specified login INI file.
func GetWorkerNodeIPsFromIni(t *testing.T, filePath string, logger *AggregatedLogger) ([]string, error) {
	value, err := GetValueFromIniFile(filePath+"/worker.ini", "WorkerServer")
	if err != nil {
		return nil, fmt.Errorf("failed to get value from worker.ini: %w", err)
	}
	logger.Info(t, fmt.Sprintf("Worker Node IPs List %q", value[1:]))
	return value[1:], nil
}

// HPCGetClusterIPs retrieves the IP addresses of the bastion server, management nodes, and login node
// from the specified file path in the provided test options, using the provided logger for logging.
// It returns the bastion server IP, a list of management node IPs, the login node IP, and any error encountered.
func HPCGetClusterIPs(t *testing.T, options *testhelper.TestOptions, logger *AggregatedLogger) (bastionIP string, managementNodeIPList []string, loginNodeIP string, err error) {
	// Retrieve the Terraform directory from the options.
	filePath := options.TerraformOptions.TerraformDir

	// Get bastion server IP and handle errors
	bastionIP, err = GetBastionServerIPFromIni(t, filePath, logger)
	if err != nil {
		return "", nil, "", fmt.Errorf("error getting bastion server IP: %v", err)
	}

	// Get management node IPs and handle errors
	managementNodeIPList, err = GetManagementNodeIPsFromIni(t, filePath, logger)
	if err != nil {
		return "", nil, "", fmt.Errorf("error getting management node IPs: %v", err)
	}

	// Get login node IP and handle errors
	loginNodeIP, err = GetLoginNodeIPFromIni(t, filePath, logger)
	if err != nil {
		return "", nil, "", fmt.Errorf("error getting login node IP: %v", err)
	}

	return bastionIP, managementNodeIPList, loginNodeIP, nil
}

// LSFGetClusterIPs retrieves the IP addresses of the bastion server, management nodes, and login node
// from the specified file path in the provided test options, using the provided logger for logging.
// It returns the bastion server IP, a list of management node IPs, the login node IP, and any error encountered.
func LSFGetClusterIPs(t *testing.T, options *testhelper.TestOptions, logger *AggregatedLogger) (bastionIP string, managementNodeIPList []string, loginNodeIP string, workerNodeIPList []string, err error) {
	// Retrieve the Terraform directory from the options.
	filePath := options.TerraformOptions.TerraformDir

	// Get bastion server IP and handle errors
	bastionIP, err = GetBastionServerIPFromIni(t, filePath, logger)
	if err != nil {
		return "", nil, "", nil, fmt.Errorf("error getting bastion server IP: %v", err)
	}

	// Get management node IPs and handle errors
	managementNodeIPList, err = GetManagementNodeIPsFromIni(t, filePath, logger)
	if err != nil {
		return "", nil, "", nil, fmt.Errorf("error getting management node IPs: %v", err)
	}

	// Get login node IP and handle errors
	loginNodeIP, err = GetLoginNodeIPFromIni(t, filePath, logger)
	if err != nil {
		return "", nil, "", nil, fmt.Errorf("error getting login node IP: %v", err)
	}

	// Get Worker Node IPs and handle errors
	workerNodeIPList, err = GetWorkerNodeIPsFromIni(t, filePath, logger)
	if err != nil {
		return "", nil, "", nil, fmt.Errorf("error getting worker node IPs: %v", err)
	}

	return bastionIP, managementNodeIPList, loginNodeIP, workerNodeIPList, nil
}

// HPCGetClusterIPsWithLDAP retrieves the IP addresses of various servers, including the LDAP server.
// from the specified file path in the provided test options, using the provided logger for logging.
// It returns the bastion server IP, a list of management node IPs, the login node IP, ldap server IP and any error encountered.
func HPCGetClusterIPsWithLDAP(t *testing.T, options *testhelper.TestOptions, logger *AggregatedLogger) (bastionIP string, managementNodeIPList []string, loginNodeIP, ldapIP string, err error) {
	// Retrieve the Terraform directory from the options.
	filePath := options.TerraformOptions.TerraformDir

	// Get the bastion server IP and handle errors.
	bastionIP, err = GetBastionServerIPFromIni(t, filePath, logger)
	if err != nil {
		return "", nil, "", "", fmt.Errorf("error getting bastion server IP: %v", err)
	}

	// Get the management node IPs and handle errors.
	managementNodeIPList, err = GetManagementNodeIPsFromIni(t, filePath, logger)
	if err != nil {
		return "", nil, "", "", fmt.Errorf("error getting management node IPs: %v", err)
	}

	// Get the login node IP and handle errors.
	loginNodeIP, err = GetLoginNodeIPFromIni(t, filePath, logger)
	if err != nil {
		return "", nil, "", "", fmt.Errorf("error getting login node IP: %v", err)
	}

	// Get the LDAP server IP and handle errors.
	ldapIP, err = GetLdapServerIPFromIni(t, filePath, logger)
	if err != nil {
		return "", nil, "", "", fmt.Errorf("error getting LDAP server IP: %v", err)
	}

	// Return the retrieved IP addresses and any error.
	return bastionIP, managementNodeIPList, loginNodeIP, ldapIP, nil
}

// LSFGetClusterIPsWithLDAP retrieves the IP addresses of various servers, including the LDAP server,
// from the specified file path in the provided test options, using the provided logger for logging.
// It returns the bastion server IP, a list of management node IPs, the login node IP, worker node IPs,
// LDAP server IP, and any error encountered.
func LSFGetClusterIPsWithLDAP(t *testing.T, options *testhelper.TestOptions, logger *AggregatedLogger) (
	bastionIP string,
	managementNodeIPList []string,
	loginNodeIP string,
	workerNodeIPList []string,
	ldapIP string,
	err error,
) {
	// Retrieve the Terraform directory from the options.
	filePath := options.TerraformOptions.TerraformDir

	// Get the bastion server IP and handle errors.
	bastionIP, err = GetBastionServerIPFromIni(t, filePath, logger)
	if err != nil {
		return "", nil, "", nil, "", fmt.Errorf("failed to get bastion server IP: %v", err)
	}

	// Get the management node IPs and handle errors.
	managementNodeIPList, err = GetManagementNodeIPsFromIni(t, filePath, logger)
	if err != nil {
		return "", nil, "", nil, "", fmt.Errorf("failed to get management node IPs: %v", err)
	}

	// Get the login node IP and handle errors.
	loginNodeIP, err = GetLoginNodeIPFromIni(t, filePath, logger)
	if err != nil {
		return "", nil, "", nil, "", fmt.Errorf("failed to get login node IP: %v", err)
	}

	// Get worker node IPs and handle errors.
	workerNodeIPList, err = GetWorkerNodeIPsFromIni(t, filePath, logger)
	if err != nil {
		return "", nil, "", nil, "", fmt.Errorf("failed to get worker node IPs: %v", err)
	}

	// Get the LDAP server IP and handle errors.
	ldapIP, err = GetLdapServerIPFromIni(t, filePath, logger)
	if err != nil {
		return "", nil, "", nil, "", fmt.Errorf("failed to get LDAP server IP: %v", err)
	}

	// Return the retrieved IP addresses and any error.
	return bastionIP, managementNodeIPList, loginNodeIP, workerNodeIPList, ldapIP, nil
}

// Getting BastionID and ComputeID from separately created brand new VPC
func GetSubnetIds(outputs map[string]interface{}) (string, string) {
	subnetDetailsList := outputs["subnet_detail_list"]
	var bastion []string
	var compute []string
	for _, val := range subnetDetailsList.(map[string]interface{}) {
		for key1, val1 := range val.(map[string]interface{}) {
			isContains := strings.Contains(key1, "bastion")
			if isContains {
				for key2, val2 := range val1.(map[string]interface{}) {
					if key2 == "id" {
						bastion = append(bastion, val2.(string))
					}
				}
			} else {
				for key2, val2 := range val1.(map[string]interface{}) {
					if key2 == "id" {
						compute = append(compute, val2.(string))
					}
				}
			}

		}
	}
	bastionsubnetId := strings.Join(bastion, ",")
	computesubnetIds := strings.Join(compute, ",")
	return bastionsubnetId, computesubnetIds
}

// Getting DNSInstanceID and CustomResolverID from separately created brand new VPC
func GetDnsCustomResolverIds(outputs map[string]interface{}) (string, string) {
	customResolverHub := outputs["custom_resolver_hub"]
	var instanceId string
	var customResolverId string
	for _, details := range customResolverHub.([]interface{}) {
		for key, val := range details.(map[string]interface{}) {
			if key == "instance_id" {
				instanceId = val.(string)
			}
			if key == "custom_resolver_id" {
				customResolverId = val.(string)
			}
		}
	}
	return instanceId, customResolverId
}

// GetClusterSecurityID retrieves the security group ID for a cluster based on the provided parameters.
// It logs in to IBM Cloud, executes a command to find the security group ID associated with the cluster prefix,
// and returns the security group ID or an error if any step fails.
func GetClusterSecurityID(t *testing.T, apiKey, region, resourceGroup, clusterPrefix string, logger *AggregatedLogger) (securityGroupID string, err error) {
	// If the resource group is "null", set a custom resource group based on the cluster prefix.
	if strings.Contains(resourceGroup, "null") {
		resourceGroup = fmt.Sprintf("%s-workload-rg", clusterPrefix)
	}

	// Log in to IBM Cloud using the API key, region, and resource group.
	if err := LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup); err != nil {
		return "", fmt.Errorf("failed to log in to IBM Cloud: %w", err)
	}

	// Determine the command to get the security group ID based on the cluster prefix.
	cmd := fmt.Sprintf("ibmcloud is security-groups | grep %s-cluster-sg | awk '{print $1}'", clusterPrefix)

	// Execute the command to retrieve the security group ID.
	output, err := exec.Command("bash", "-c", cmd).CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("failed to retrieve security group ID: %w", err)
	}

	// Trim and check if the result is empty.
	securityGroupID = strings.TrimSpace(string(output))
	if securityGroupID == "" {
		return "", fmt.Errorf("no security group ID found for cluster prefix %s", clusterPrefix)
	}

	logger.Info(t, "securityGroupID: "+securityGroupID)

	return securityGroupID, nil
}

// UpdateSecurityGroupRules updates the security group with specified port and CIDR based on the provided parameters.
// It logs in to IBM Cloud, determines the appropriate command, and executes it to update the security group.
// Returns an error if any step fails.
func UpdateSecurityGroupRules(t *testing.T, apiKey, region, resourceGroup, clusterPrefix, securityGroupId, cidr, minPort, maxPort string, logger *AggregatedLogger) (err error) {
	// If the resource group is "null", set a custom resource group based on the cluster prefix.
	if strings.Contains(resourceGroup, "null") {
		resourceGroup = fmt.Sprintf("%s-workload-rg", clusterPrefix)
	}

	// Log in to IBM Cloud using the API key, region, and resource group.
	if err := LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup); err != nil {
		return fmt.Errorf("failed to log in to IBM Cloud: %w", err)
	}

	// Determine the command to add a rule to the security group with the specified port and CIDR.
	addRuleCmd := fmt.Sprintf("ibmcloud is security-group-rule-add %s inbound tcp --remote %s --port-min %s --port-max %s", securityGroupId, cidr, minPort, maxPort)

	// Execute the command to update the security group.
	output, err := exec.Command("bash", "-c", addRuleCmd).CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to update security group with port and CIDR: %w", err)
	}

	logger.Info(t, "security group updated output: "+strings.TrimSpace(string(output)))

	// Verify if the output contains the expected CIDR.
	if !VerifyDataContains(t, strings.TrimSpace(string(output)), cidr, logger) {
		return fmt.Errorf("failed to update security group CIDR: %s", string(output))
	}

	// Verify if the output contains the expected minimum port.
	if !VerifyDataContains(t, strings.TrimSpace(string(output)), minPort, logger) {
		return fmt.Errorf("failed to update security group port: %s", string(output))
	}

	return nil
}

// GetCustomResolverID retrieves the custom resolver ID for a VPC based on the provided cluster prefix.
// It logs in to IBM Cloud, retrieves the DNS instance ID, and then fetches the custom resolver ID.
// Returns the custom resolver ID and any error encountered.
func GetCustomResolverID(t *testing.T, apiKey, region, resourceGroup, clusterPrefix string, logger *AggregatedLogger) (customResolverID string, err error) {
	// If the resource group is "null", set a custom resource group based on the cluster prefix.
	if strings.Contains(resourceGroup, "null") {
		resourceGroup = fmt.Sprintf("%s-workload-rg", clusterPrefix)
	}

	// Log in to IBM Cloud using the API key, region, and resource group.
	if err := LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup); err != nil {
		return "", fmt.Errorf("failed to log in to IBM Cloud: %w", err)
	}

	// Command to get the DNS instance ID based on the cluster prefix.
	dnsInstanceCmd := fmt.Sprintf("ibmcloud dns instances | grep %s | awk '{print $2}'", clusterPrefix)
	dnsInstanceIDOutput, err := exec.Command("bash", "-c", dnsInstanceCmd).CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("failed to retrieve DNS instance ID: %w", err)
	}

	// Trim whitespace and check if we received a valid DNS instance ID.
	dnsInstanceID := strings.TrimSpace(string(dnsInstanceIDOutput))
	if dnsInstanceID == "" {
		return "", fmt.Errorf("no DNS instance ID found for cluster prefix %s", clusterPrefix)
	}

	// Command to get custom resolvers for the DNS instance ID.
	customResolverCmd := fmt.Sprintf("ibmcloud dns custom-resolvers -i %s | awk 'NR>3 {print $1}'", dnsInstanceID)
	customResolverIDOutput, err := exec.Command("bash", "-c", customResolverCmd).CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("failed to retrieve custom resolver ID: %w", err)
	}

	// Trim whitespace and check if we received a valid custom resolver ID.
	customResolverID = strings.TrimSpace(string(customResolverIDOutput))
	if customResolverID == "" {
		return "", fmt.Errorf("no custom resolver ID found for DNS instance ID %s", dnsInstanceID)
	}
	logger.Info(t, "customResolverID: "+customResolverID)

	return customResolverID, nil
}

// RetrieveAndUpdateSecurityGroup retrieves the security group ID based on the provided cluster prefix,
// then updates the security group with the specified port and CIDR.
// It logs in to IBM Cloud, determines the appropriate commands, and executes them.
// Returns an error if any step fails.
func RetrieveAndUpdateSecurityGroup(t *testing.T, apiKey, region, resourceGroup, clusterPrefix, cidr, minPort, maxPort string, logger *AggregatedLogger) error {
	// If the resource group is "null", set a custom resource group based on the cluster prefix.
	if strings.Contains(resourceGroup, "null") {
		resourceGroup = fmt.Sprintf("%s-workload-rg", clusterPrefix)
	}

	// Log in to IBM Cloud using the API key, region, and resource group.
	if err := LoginIntoIBMCloudUsingCLI(t, apiKey, region, resourceGroup); err != nil {
		return fmt.Errorf("failed to log in to IBM Cloud: %w", err)
	}

	// Command to get the security group ID based on the cluster prefix.
	getSecurityGroupIDCmd := fmt.Sprintf("ibmcloud is security-groups | grep %s-cluster-sg | awk '{print $1}'", clusterPrefix)
	securityGroupIDBytes, err := exec.Command("bash", "-c", getSecurityGroupIDCmd).CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to retrieve security group ID: %w", err)
	}

	securityGroupID := strings.TrimSpace(string(securityGroupIDBytes))
	if securityGroupID == "" {
		return fmt.Errorf("no security group ID found for cluster prefix %s", clusterPrefix)
	}

	logger.Info(t, "securityGroupID: "+securityGroupID)

	// Command to add a rule to the security group with the specified port and CIDR.
	addRuleCmd := fmt.Sprintf("ibmcloud is security-group-rule-add %s inbound tcp --remote %s --port-min %s --port-max %s", securityGroupID, cidr, minPort, maxPort)
	outputBytes, err := exec.Command("bash", "-c", addRuleCmd).CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to update security group with port and CIDR: %w", err)
	}

	output := strings.TrimSpace(string(outputBytes))
	logger.Info(t, "security group updated output: "+output)

	// Combine output verification steps.
	if !VerifyDataContains(t, output, cidr, logger) || !VerifyDataContains(t, output, minPort, logger) {
		return fmt.Errorf("failed to update security group with CIDR %s and port %s: %s", cidr, minPort, output)
	}

	return nil
}
