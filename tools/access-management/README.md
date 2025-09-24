# IAM Permissions Assignment for LSF Deployment

#### Before deploying an IBM Spectrum LSF cluster, specific IAM permissions must be assigned to either a user or an access group. The automation script enables this process.

User has the flexibility to run the specific scripts to gain the required IAM permissions to perform the LSF deployment. The automation ensures that if the user has a certain permissions, then the script will omit them and add only the required permissions to perform the deployment.

For example, for the App configuration service, the user requires Administrator and Manager permissions. If the user already has the Administrator permission, then the script will omit this and provide only Manager permission.

### Benefits of the scripts:

#### Interactive input collection - The script prompts for the IBMid (admin email), Resource Group ID, Account ID, and target (User or Access Group).

#### Permission check - The script verifies that the admin has account-level Administrator rights which is required to assign policies.

#### Assigns required permissions for LSF deployment - This script grants the appropriate permissions across IBM Cloud services that LSF depends upon (for example, VPC, COS, DNS services, KMS, Secrets Manager, and Sysdig Monitoring).

#### Avoids duplicates - The script skips the assignment if a matching policy already exists.

You can get the scripts by performing gitclone on the branch:

```
git clone -b main https://github.com/terraform-ibm-modules/terraform-ibm-hpc.git
```

1. Navigate to cd tools/access-management, you will get the permissions.sh file.

2. Login to the IBM Cloud with your API key. Run the following command:

```
ibmcloud login --apikey <YOUR_API_KEY> -g <RESOURCE_GROUP>
chmod +x permissions.sh
./permissions.sh
```

3. Enter the admin email or IBMid.

4. Enter the Resource group and Account ID.

For the Account ID, login to the IBM Cloud account by using your unique credentials. Go to Manage > Account > Account settings. You will find the Account ID.

5. You will be asked to assign the roles:

```
Access Group - Select this option, if you want to assign the access to the entire access group.
User - Select this option, if you want to assign the access to an individual user.
Select the required option.
```

6. Enter the target user email, if you select the option 2.

7. User policy is successfully created.

If the user skips to enter the RESOURCE_GROUP_ID or the ACCOUNT_ID, then script displays the error message:

```
:x: RESOURCE_GROUP_ID is required.
:x: ACCOUNT_ID is required.
```

This script ensures the user or access group has all the required IAM permissions to successfully deploy an LSF environment.
