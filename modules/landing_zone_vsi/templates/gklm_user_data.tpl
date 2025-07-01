#!/bin/bash

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

#!/bin/bash
echo "0 $(hostname) 0" > /home/klmdb42/sqllib/db2nodes.cfg
systemctl start db2c_klmdb42.service
sleep 10
systemctl status db2c_klmdb42.service
sleep 10
#Copying SSH for passwordless authentication
echo "${storage_private_key_content}" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
echo "${bastion_public_key_content}" >> ~/.ssh/authorized_keys
echo "StrictHostKeyChecking no" >> ~/.ssh/config
reboot
