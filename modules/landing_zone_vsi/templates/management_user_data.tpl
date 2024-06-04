#!/usr/bin/bash

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

logfile=/tmp/user_data.log
echo "Export user data (variable values)"
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile

### EXPORT_USER_DATA ###

#input parameters
rc_cidr_block="${rc_cidr_block}"
cluster_private_key_content="${cluster_private_key_content}"
cluster_public_key_content="${cluster_public_key_content}"
hyperthreading="${hyperthreading}"
network_interface=${network_interface}
dns_domain="${dns_domain}"

echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile
