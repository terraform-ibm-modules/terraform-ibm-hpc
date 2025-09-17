# Deploying and Connecting to LSF Environment via CLI

### Notes:

The <cluster_prefix> must be 16 characters or fewer, i.e. abc-lsf

The catalog_values_<environment_type>_deployment.json specifies the configuation of the LSF environment. Please review to avoid unexpected costs.

### Deployment Types:

#### Minimal:
Deploys the smallest possible environment (a single management instance) for the fastest setup. All optional services (observability, logging, SCC, Atracker, Ldap etc.) are disabled.

#### Demo:
Showcases the full set of capabilities. All optional services (observability, logging, SCC, etc.) are enabled. Deployment takes longer compared to minimal.

#### Production:
Allows customization for production-grade deployments. Optional services like observability, logging, and SCC are enabled by default but can be tailored as required.

All JSON files are customizable (users can tweak configs as needed).
But the .env file is mandatory because that’s where the required variables must always be filled.

## Step 1. Fill the .env file

```
##############################################################################
# Environment Configuration

# Step 1: Update the variables below as needed.
# Step 2: If you require additional optional variables, update them directly
#         in the JSON file(s) for your deployment type.
# Step 3: Always validate the JSON file before running the script.
##############################################################################

# IBM Cloud API key
API_KEY="YOUR_API_KEY"

# Account and resource details
ACCOUNT_GUID="ACCOUNT_GUID"
ZONES="ZONES"
RESOURCE_GROUP="RESOURCE_GROUP"

# SSH key name (must exist in your account)
SSH_KEY="SSH_KEY"

# Template JSON file (choose as per your deployment type)
TEMPLATE_FILE="catalog_values_minimal_deployment.json"

# LSF tile version locator
# Example below is for 3.0.0 version
LSF_TILE_VERSION="1082e7d2-5e2f-0a11-a3bc-f88a8e1931fc.6c26cd4c-4f72-45e5-8bde-77387aa05138-global"

# App Center GUI password
# Rules: Minimum 8 characters, at least 1 uppercase, 1 lowercase, 1 number,
# and 1 special character (!@#$%^&*()_+=-). No spaces allowed.
APP_CENTER_GUI_PASSWORD="APP_CENTER_GUI_PASSWORD"
```

## Step 2. Deploy the LSF Environment:
```
1. chmod +x create_lsf_environment.sh
2. ./create_lsf_environment.sh <cluster_prefix>
```

## Step 3. Connect to the LSF Cluster and Run Jobs

Now that your environment is set up, you can connect to the LSF cluster and perform operations such as submitting jobs, monitoring workloads, viewing infrastructure details. etc.

#### 1. To view the infra details

```
chmod +x show.sh
 ./show.sh <cluster_prefix>
```

#### 2. Copy the job submission script to the cluster

```
chmod +x cp.sh
 ./cp.sh <cluster_prefix> submit.sh
```

#### 3. Jump to the LSF Environment

```
chmod +x jump.sh
 ./jump.sh <cluster_prefix>
```

#### 4. Submit jobs

```
sh submit.sh
bjobs
lshosts -w
```
