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
echo "${encoded_content}" | base64 -d > ${target_dir}/compressed_compute.tar.gz

# Extract the tar.gz file
echo "Unpacking the contents of the compressed file"
tar -xzf ${target_dir}/compressed_compute.tar.gz -C ${target_dir}
rm -f ${target_dir}/compressed_compute.tar.gz

echo "Packer installation started"

# Download and unzip Packer
wget https://releases.hashicorp.com/packer/1.11.1/packer_1.11.1_linux_amd64.zip
unzip packer_1.11.1_linux_amd64.zip

# Move Packer to /usr/local/bin
sudo mv packer /usr/local/bin/

# Create a symlink to /usr/sbin
sudo ln -sf /usr/local/bin/packer /usr/sbin/packer

sleep 60

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
