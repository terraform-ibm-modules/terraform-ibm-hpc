#!/bin/bash

#################################################################################
# This script allows users to customize images by installing software packages,
# dependencies, and configurations specific to their requirements.
# Please put your logic below based on the OS you provided for 'source_image_name'
##################################################################################

if grep -q 'ID="rhel"' /etc/os-release || grep -q 'ID="rocky"' /etc/os-release; then
    echo "================= Running user customization script ================="
    # Add your commands here for Red Hat or Rocky Linux
else
    echo "================= Running user customization script ================="
    # Add your commands here for Ubuntu
fi
