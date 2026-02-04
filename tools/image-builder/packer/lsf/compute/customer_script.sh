#!/bin/bash

#################################################################################
# This script allows users to customize images by installing software packages,
# dependencies, and configurations specific to their requirements.
# Please put your logic below based on the OS you provided for 'source_image_name'
##################################################################################

if grep -q 'ID="rhel"' /etc/os-release || grep -q 'ID="rocky"' /etc/os-release; then
    echo "================= Running user customization script ================="
    # Add your commands here for Red Hat or Rocky Linux
    # Steps from: https://wiki.crowncloud.net/?How_to_Install_Python_3_12_on_CentOS_Stream_8
    dnf install -y xz-devel gcc openssl-devel bzip2-devel libffi-devel wget tar make docker
    cd /tmp
    wget https://www.python.org/ftp/python/3.12.0/Python-3.12.0.tgz
    tar -xf Python-3.12.0.tgz
    cd Python-3.12.0
    ./configure --enable-optimizations
    make -j $(nproc)
    make altinstall
    pip3.12 install --upgrade pip
    # pip3.12 install requests dotenv pyscf ffsim matplotlib qiskit_ibm_runtime
    pip3.12 install requests dotenv pyscf ffsim numpy matplotlib qiskit[visualization] qiskit_ibm_runtime qiskit_addon_sqd
    cd /tmp
    rm -rf Python-3.12.0
    # dnf install -y python36-devel python36-devel
    # dnf module enable python312
    # dnf install -y python3.12-*
    # pip-3.12 install requests dotenv pyscf ffsim matplotlib qiskit_ibm_runtime
else
    echo "================= Running user customization script ================="
    # Add your commands here for Ubuntu
fi