#!/usr/bin/bash

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

#!/usr/bin/env bash
if grep -E -q "CentOS|Red Hat" /etc/os-release
then
    USER=vpcuser
elif grep -q "Ubuntu" /etc/os-release
then
    USER=ubuntu
fi
sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please login as the user \\\\\"$USER\\\\\" rather than the user \\\\\"root\\\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys

#input parameters
echo "${ssh_public_key_content}" >> home/$USER/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >> /home/$USER/.ssh/config
