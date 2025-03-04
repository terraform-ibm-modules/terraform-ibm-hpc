#!/usr/bin/bash

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

### EXPORT_USER_DATA ###

#input parameters
VPC_APIKEY_VALUE="${vpc_apikey_value}"
RESOURCE_RECORDS_APIKEY_VALUE="${vpc_apikey_value}"
management_node_count="${management_node_count}"
api_endpoint_eu_de="${api_endpoint_eu_de}"
api_endpoint_us_east="${api_endpoint_us_east}"
api_endpoint_us_south="${api_endpoint_us_south}"
imageID="${image_id}"
subnetID="${subnet_id}"
subnetId="${subnet_id}"
vpcID="${vpc_id}"
securityGroupID="${security_group_id}"
sshkey_ID="${sshkey_id}"
regionName="${region_name}"
zoneName="${zone_name}"
zone="${zone_name}"
# the CIDR block for dyanmic hosts
rc_cidr_block="${rc_cidr_block}"
# the maximum allowed dynamic hosts created by RC
rc_max_num=${rc_max_num}
rc_rg=${rc_rg}
cluster_name="${cluster_name}"
ce_project_guid="${ce_project_guid}"
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
management_ip=${management_ip}
management_hostname=${management_hostname}
management_cand_ips=${management_cand_ips}
management_cand_hostnames=${management_cand_hostnames}
login_ip=${login_ip}
login_hostname=${login_hostname}
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
ldap_server_cert="${ldap_server_cert}"
ldap_server_hostname="${ldap_server_hostname}"
ldap_basedns="${ldap_basedns}"
bootdrive_crn="${bootdrive_crn}"
# Observability
observability_monitoring_enable="${observability_monitoring_enable}"
observability_monitoring_on_compute_nodes_enable="${observability_monitoring_on_compute_nodes_enable}"
cloud_monitoring_access_key="${cloud_monitoring_access_key}"
cloud_monitoring_ingestion_url="${cloud_monitoring_ingestion_url}"
cloud_monitoring_prws_key="${cloud_monitoring_prws_key}"
cloud_monitoring_prws_url="${cloud_monitoring_prws_url}"
cloud_logs_ingress_private_endpoint="${cloud_logs_ingress_private_endpoint}"
observability_logs_enable_for_management="${observability_logs_enable_for_management}"
observability_logs_enable_for_compute="${observability_logs_enable_for_compute}"
solution="${solution}"
rc_ncores="${rc_ncores}"
rc_ncpus="${rc_ncpus}"
rc_memInMB="${rc_mem_in_mb }"
rc_profile="${rc_profile}"
