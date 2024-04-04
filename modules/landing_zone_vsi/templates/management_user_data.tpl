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
VPC_APIKEY_VALUE="${vpc_apikey_value}"
RESOURCE_RECORDS_APIKEY_VALUE="${vpc_apikey_value}"
management_node_count="${management_node_count}"
api_endpoint_eu_de="${api_endpoint_eu_de}"
api_endpoint_us_east="${api_endpoint_us_east}"
api_endpoint_us_south="${api_endpoint_us_south}"
imageID="${image_id}"
subnetID="${subnet_id}"
subnetID_2="${subnet_id_2}"
vpcID="${vpc_id}"
securityGroupID="${security_group_id}"
sshkey_ID="${sshkey_id}"
regionName="${region_name}"
zoneName="${zone_name}"
zoneName_2="${zone_name_2}"
# the CIDR block for dyanmic hosts
rc_cidr_block="${rc_cidr_block}"
rc_cidr_block_2="${rc_cidr_block_2}"
# the maximum allowed dynamic hosts created by RC
rc_maxNum=${rc_maxNum}
rc_rg=${rc_rg}
cluster_name="${cluster_name}"
cluster_prefix="${cluster_prefix}"
cluster_private_key_content="${cluster_private_key_content}"
cluster_public_key_content="${cluster_public_key_content}"
bastion_public_key_content="${bastion_public_key_content}"
hyperthreading="${hyperthreading}"
network_interface=${network_interface}
dns_domain="${dns_domain}"
mount_path="${mount_path}"
custom_file_shares="${custom_file_shares}"
custom_mount_paths="${custom_mount_paths}"
contract_id="${contract_id}"
app_center_gui_pwd="${app_center_gui_pwd}"
enable_app_center="${enable_app_center}"
login_ip_address="${login_ip_address}"
# PAC High Availability
app_center_high_availability="${app_center_high_availability}"
db_adminuser="${db_adminuser}"
db_adminpassword="${db_adminpassword}"
db_hostname="${db_hostname}"
db_port="${db_port}"
db_name="${db_name}"
db_user="${db_user}"
db_password="${db_password}"
db_certificate="${db_certificate}"
# LDAP Server
enable_ldap="${enable_ldap}"
ldap_server_ip="${ldap_server_ip}"
ldap_basedns="${ldap_basedns}"
bootdrive_crn="${bootdrive_crn}"
alb_hostname="${alb_hostname}"
echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile
