
# IBM Cloud HPC - OnePipeline(Tekton)

## Prerequisites

Ensure the following are configured on your DevOps:

- **IBM Cloud Account**
- **Continuous Delivery**
- **Access role with resource_group**

## Link for setup DevOps
```
https://cloud.ibm.com/devops/getting-started?env_id=ibm:yp:eu-de
```

## Set up Your Go Project

1. Login to IBMCloud
2. Navigate to Navigation Menu on Left hand side and expand. Then go to DevOps → Toolchains
3. On the Toolchain page select Resource Group and Location where Toolchain has to create
4. Click Create toolchain and it will redirect to Create a Toolchain page
5. After successfull redirect to Toolchain Template collections, select Build your own toolchain
6. On Build your own toolchain page, provide Toolchain name, Resource Group, Region
7. Click Create it will create pipeline.

## Actions on the OnePipeline

1. When PR raised to the develop branch from feature branch, pipeline with trigger and it will run PR_TEST related testcases on top of feature branch
2. When Commit/Push happens to develop branch, pipeline will trigger and it will run all the PR_TEST and OTHER_TEST testcases

### Setup required parameters to run pipeline

1. ibmcloud-api
2. ssh_keys
3. cluster_prefix
4. zone
5. resource_group
6. cluster_id
7. reservation_id

For additional assistance, contact the project maintainers.
