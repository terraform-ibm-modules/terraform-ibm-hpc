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
dns_domain="${dns_domain}"
cluster_private_key_content="${cluster_private_key_content}"
cluster_public_key_content="${cluster_public_key_content}"
cluster_name="${cluster_name}"
mount_path="${mount_path}"
custom_mount_paths="${custom_mount_paths}"
custom_file_shares="${custom_file_shares}"
enable_ldap="${enable_ldap}"
network_interface="${network_interface}"
rc_cidr_block="${rc_cidr_block}"
cluster_prefix="${cluster_prefix}"
ldap_server_ip="${ldap_server_ip}"
ldap_basedns="${ldap_basedns}"
hyperthreading="${hyperthreading}"
management_hostname=${management_hostname}
observability_monitoring_enable="${observability_monitoring_enable}"
observability_monitoring_on_compute_nodes_enable="${observability_monitoring_on_compute_nodes_enable}"
cloud_monitoring_access_key="${cloud_monitoring_access_key}"
cloud_monitoring_ingestion_url="${cloud_monitoring_ingestion_url}"
cloud_logs_ingress_private_endpoint="${cloud_logs_ingress_private_endpoint}"
observability_logs_enable_for_compute="${observability_logs_enable_for_compute}"
VPC_APIKEY_VALUE="${VPC_APIKEY_VALUE}"
echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile
