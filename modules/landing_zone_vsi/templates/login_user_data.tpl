#!/usr/bin/bash
###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

logfile=/tmp/user_data.log
echo "Export user data (variable values)"
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile

%EXPORT_USER_DATA%
#input parameters
network_interface=${network_interface}
dns_domain="${dns_domain}"
cluster_private_key_content="${cluster_private_key_content}"
cluster_public_key_content="${cluster_public_key_content}"
mount_path="${mount_path}"
enable_ldap="${enable_ldap}"
network_interface=""${network_interface}""
rc_cidr_block="${rc_cidr_block}"
rc_cidr_block_1="${rc_cidr_block_1}"
cluster_prefix="${cluster_prefix}"
ldap_server_ip="${ldap_server_ip}"
ldap_basedns="${ldap_basedns}"
hyperthreading="${hyperthreading}"
echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile
