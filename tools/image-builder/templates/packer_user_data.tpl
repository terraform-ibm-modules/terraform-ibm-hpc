#!/usr/bin/bash

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# Install required packages

export HOME=/root  # Setting this as a path because got to see error on user data scripts, we can revisit this logic later

sudo yum install -y wget unzip jq

# Decode and extract the base64-encoded content

sudo mkdir -p ${target_dir}
echo "Decoding and saving base64-encoded content [necessary to retrieve the original compressed file]"
echo "${encoded_compute}" | base64 -d > ${target_dir}/compressed_compute.tar.gz

# Extract the tar.gz file
echo "Unpacking the contents of the compressed file"
tar -xzf ${target_dir}/compressed_compute.tar.gz -C ${target_dir}
rm -f ${target_dir}/compressed_compute.tar.gz

echo "Packer installation started"

# Download and unzip Packer
packer_version=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/packer | jq -r .current_version)
wget https://releases.hashicorp.com/packer/"$packer_version"/packer_"$packer_version"_linux_amd64.zip
unzip packer_"$packer_version"_linux_amd64.zip

# Move Packer to /usr/local/bin
sudo mv packer /usr/local/bin/

# Create a symlink to /usr/sbin
sudo ln -sf /usr/local/bin/packer /usr/sbin/packer

install_with_retry() {
    local cmd="$1"
    local retries="$2"
    local count=0

    until $cmd || [ $count -eq "$retries" ]; do
        echo "Installation failed. Retrying..."
        sleep 5  # Adjust sleep duration between retries as needed
        count=$((count + 1))
    done

    if [ $count -eq "$retries" ]; then
        echo "Failed to install after $retries attempts. Exiting."
        exit 1
    fi
}

echo $'***** Installing s3fs *****\n'
sudo rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-8
sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
install_with_retry "sudo yum install -y s3fs-fuse" 3
rpm -qa | grep epel-release
rpm -qa | grep s3fs-fuse

echo "======================Cloning HPC public repo====================="

sudo yum install git -y
mkdir /HPCaaS
cd /HPCaaS
git clone https://github.com/terraform-ibm-modules/terraform-ibm-hpc.git
cd /HPCaaS/terraform-ibm-hpc/solutions/hpc
echo "======================Cloning HPC public repo completed====================="

echo "======================Installing terraform====================="
git clone --depth=1 https://github.com/tfutils/tfenv.git ~/.tfenv
echo "export PATH=$PATH:$HOME/.tfenv/bin" >> ~/.bashrc
ln -s ~/.tfenv/bin/* /usr/local/bin
tfenv install latest
tfenv use latest
terraform --version

echo "====================== Triggering mounting of Cos Bucket ====================="
mkdir /wes-hpc
s3fs custom-image-builder /wes-hpc -o url=https://s3.direct.us-south.cloud-object-storage.appdomain.cloud -o ro -o public_bucket=1
mkdir -p /HPCaaS/terraform-ibm-hpc/tools/tests
cp -r /wes-hpc/tests/* /HPCaaS/terraform-ibm-hpc/tools/tests/
ls -ltr /HPCaaS/terraform-ibm-hpc/tools/tests/
echo "====================== Cos Bucket mounting completed ====================="

cd /var/packer/hpcaas/compute

sudo -E packer init . && sudo -E packer build \
    -var "ibm_api_key=${ibm_api_key}" \
    -var "vpc_region=${vpc_region}" \
    -var "resource_group_id=${resource_group_id}" \
    -var "vpc_subnet_id=${vpc_subnet_id}" \
    -var "source_image_name=${source_image_name}" \
    -var "install_sysdig=${install_sysdig}" \
    -var "security_group_id=${security_group_id}" \
    -var "image_name=${image_name}" .

echo "========== Generating SSH key ========="
mkdir -p /HPCaaS/artifacts/.ssh
ssh-keygen -t rsa -N '' -f /HPCaaS/artifacts/.ssh/id_rsa <<< y

RANDOM_SUFFIX=$(head /dev/urandom | tr -dc 'a-z' | head -c 4)
CICD_SSH_KEY="hpc-packer-$RANDOM_SUFFIX"

PACKER_FIP=$(curl -s ifconfig.io)

echo "========== Installing IBM cloud CLI ========="
curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
ibmcloud plugin install infrastructure-service
ibmcloud login --apikey ${ibm_api_key} -r ${vpc_region}
echo "========== Uploading SSH key to IBM cloud ========="
ibmcloud is key-create $CICD_SSH_KEY @/HPCaaS/artifacts/.ssh/id_rsa.pub --resource-group-name ${resource_group}

cd /HPCaaS/terraform-ibm-hpc/tools/tests
git submodule update --init

sudo yum update -y

echo "***** Installing Golang *****"

if [ ! -d "$(pwd)/go" ]; then
    wget https://go.dev/dl/go1.23.1.linux-amd64.tar.gz
    tar -C $(pwd)/ -xzf go1.23.1.linux-amd64.tar.gz
    echo "export PATH=\$PATH:$(pwd)/go/bin:\$HOME/go/bin" >> ~/.bashrc
    echo "export GOROOT=$(pwd)/go" >> ~/.bashrc
    source ~/.bashrc
fi

echo "========== Executing Go function to validate the image through HPC deployment ========="
export TF_VAR_ibmcloud_api_key=${ibm_api_key}

if [ "${solution}" != "lsf" ]; then
    if [ "${private_catalog_id}" ]; then
        SOLUTION=${solution} PREFIX=${prefix} CLUSTER_ID=${cluster_id} RESERVATION_ID=${reservation_id} SSH_FILE_PATH="/HPCaaS/artifacts/.ssh/id_rsa" REMOTE_ALLOWED_IPS=$PACKER_FIP SSH_KEYS=$CICD_SSH_KEY CATALOG_VALIDATE_SSH_KEY=${catalog_validate_ssh_key} ZONES=${zones} RESOURCE_GROUP=${resource_group} COMPUTE_IMAGE_NAME=${image_name} PRIVATE_CATALOG_ID=${private_catalog_id} VPC_ID=${vpc_id} SUBNET_ID=${vpc_subnet_id} SOURCE_IMAGE_NAME=${source_image_name} go test -v -timeout 900m -parallel 4 -run "TestRunHpcDeploymentForCustomImageBuilder" | tee hpc_log_$(date +%d-%m-%Y-%H-%M-%S).log
    else
        SOLUTION=${solution} PREFIX=${prefix} CLUSTER_ID=${cluster_id} RESERVATION_ID=${reservation_id} SSH_FILE_PATH="/HPCaaS/artifacts/.ssh/id_rsa" REMOTE_ALLOWED_IPS=$PACKER_FIP SSH_KEYS=$CICD_SSH_KEY ZONES=${zones} RESOURCE_GROUP=${resource_group} COMPUTE_IMAGE_NAME=${image_name} SOURCE_IMAGE_NAME=${source_image_name} go test -v -timeout 900m -parallel 4 -run "TestRunHpcDeploymentForCustomImageBuilder" | tee hpc_log_$(date +%d-%m-%Y-%H-%M-%S).log
    fi
else
    if [ "${private_catalog_id}" ]; then
        SOLUTION=${solution} IBM_CUSTOMER_NUMBER=${ibm_customer_number} PREFIX=${prefix} CLUSTER_ID=${cluster_id} SSH_FILE_PATH="/HPCaaS/artifacts/.ssh/id_rsa" REMOTE_ALLOWED_IPS=$PACKER_FIP SSH_KEYS=$CICD_SSH_KEY CATALOG_VALIDATE_SSH_KEY=${catalog_validate_ssh_key} ZONES=${zones} RESOURCE_GROUP=${resource_group} COMPUTE_IMAGE_NAME=${image_name} PRIVATE_CATALOG_ID=${private_catalog_id} VPC_ID=${vpc_id} SUBNET_ID=${vpc_subnet_id} SOURCE_IMAGE_NAME=${source_image_name} go test -v -timeout 900m -parallel 4 -run "TestRunHpcDeploymentForCustomImageBuilder" | tee hpc_log_$(date +%d-%m-%Y-%H-%M-%S).log
    else
        SOLUTION=${solution} IBM_CUSTOMER_NUMBER=${ibm_customer_number} PREFIX=${prefix} CLUSTER_ID=${cluster_id} SSH_FILE_PATH="/HPCaaS/artifacts/.ssh/id_rsa" REMOTE_ALLOWED_IPS=$PACKER_FIP SSH_KEYS=$CICD_SSH_KEY ZONES=${zones} RESOURCE_GROUP=${resource_group} COMPUTE_IMAGE_NAME=${image_name} SOURCE_IMAGE_NAME=${source_image_name} go test -v -timeout 900m -parallel 4 -run "TestRunHpcDeploymentForCustomImageBuilder" | tee hpc_log_$(date +%d-%m-%Y-%H-%M-%S).log
    fi
fi
echo "========== Deleting the SSH key ========="

ibmcloud is key-delete $CICD_SSH_KEY -f