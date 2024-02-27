#!/bin/sh
###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

# Useful variables that reference the main GUI and PERF Manager folders.
LSF_SUITE_TOP="/opt/ibm/lsfsuite"
LSF_SUITE_GUI="${LSF_SUITE_TOP}/ext/gui"
LSF_SUITE_GUI_CONF="${LSF_SUITE_GUI}/conf"
LSF_SUITE_PERF="${LSF_SUITE_TOP}/ext/perf"
LSF_SUITE_PERF_CONF="${LSF_SUITE_PERF}/conf"
LSF_SUITE_PERF_BIN="${LSF_SUITE_PERF}/1.2/bin"

db_certificate_file=${LSF_SUITE_GUI_CONF}/cert.pem

# Function that dump the ICD certificate in the $db_certificate_file
create_certificate() {
    # Dump the CA certificate in the ${db_certificate_file} file and set permissions
    echo ${db_certificate} | base64 -d > ${db_certificate_file}
    chown lsfadmin:lsfadmin ${db_certificate_file}
    chmod 644 ${db_certificate_file}

}

# Function for creating PAC database in the IBM Cloud Database (ICD) service when High Availability is enabled.
# It is invoked when ${enable_app_center} and ${enable_high_availability} are both true.
create_appcenter_database() {
    # Required SQL commands to create the PAC database in the IBM Cloud Database (ICD) instance.
    local create_db_command="CREATE DATABASE ${db_name} default character set utf8 default collate utf8_bin;"
    local commands=(
        "CREATE USER ${db_user}@'%' IDENTIFIED WITH mysql_native_password BY '${db_password}';"
        "CREATE USER ${db_user}@'localhost' IDENTIFIED WITH mysql_native_password BY '${db_password}';"
        "GRANT ALL ON ${db_name}.* TO ${db_user}@'%';"
        "GRANT ALL ON ${db_name}.* TO ${db_user}@'localhost';"
        "source ${LSF_SUITE_PERF}/ego/1.2/DBschema/MySQL/egodata.sql;"
        "source ${LSF_SUITE_PERF}/lsf/10.0/DBschema/MySQL/lsfdata.sql;"
        "source ${LSF_SUITE_PERF}/lsf/10.0/DBschema/MySQL/lsf_sql.sql;"
        "source ${LSF_SUITE_GUI}/DBschema/MySQL/create_schema.sql;"
        "source ${LSF_SUITE_GUI}/DBschema/MySQL/create_pac_schema.sql;"
        "source ${LSF_SUITE_GUI}/DBschema/MySQL/init.sql;"
    )

    # On ICD you cannot change system variables so we need to comment 736 line in /opt/ibm/lsfsuite/ext/gui/DBschema/MySQL/create_pac_schema.sql
    sed -i "s|SET GLOBAL group_concat_max_len = 1000000;|/* SET GLOBAL group_concat_max_len = 1000000; */|" /opt/ibm/lsfsuite/ext/gui/DBschema/MySQL/create_pac_schema.sql
    # Create the PAC database
    echo "${create_db_command}" | MYSQL_PWD="${db_adminpassword}" mysql --host="${db_hostname}" --port="${db_port}" --user="${db_adminuser}" --ssl-ca="${db_certificate_file}" ibmclouddb
    # Create the pacuser, grant him all the required privileges, then create the schema and tables
    for command in "${commands[@]}"; do
        echo "${command}" | MYSQL_PWD="${db_adminpassword}" mysql --host="${db_hostname}" --port="${db_port}" --user="${db_adminuser}" --ssl-ca="${db_certificate_file}" pac
    done
}

# Configures the GUI JDBC datasource file ${LSF_SUITE_PERF_CONF}/datasource.xml
# to reference the IBM Cloud Database (ICD) instance. If ${enable_app_center} and
# ${enable_high_availability} are both true, updates the connection string to
# point to the remote database service instead of the local MySQL server.
configure_icd_datasource() {
    local default_connection_string="jdbc:mariadb://localhost:3306/pac?useUnicode=true&amp;characterEncoding=UTF-8&amp;serverTimezone=GMT"
    local icd_connection_string="jdbc:mariadb://${db_hostname}:${db_port}/${db_name}?useUnicode=true\&amp;characterEncoding=UTF-8\&amp;serverTimezone=GMT\&amp;requireSSL=true\&amp;useSSL=true\&amp;serverSslCert=${db_certificate_file}"

    # Change the connection string to use ICD
    sed -i "s!Connection=\"${default_connection_string}\"!Connection=\"${icd_connection_string}\"!" ${LSF_SUITE_PERF_CONF}/datasource.xml
    # Change the Cipher algorithm to AES128 in the Datasource definition
    sed -i "s|Cipher=\".*\"|Cipher=\"aes128\"|" ${LSF_SUITE_PERF_CONF}/datasource.xml
    # Encrypt the Database user and password with AES128 Cipher. The encryptTool.sh script requires the setting of the JAVA_HOME
    db_user_aes128=$(source ${LSF_SUITE_TOP}/ext/profile.platform; ${LSF_SUITE_PERF_BIN}/encryptTool.sh "${db_user}")
    db_password_aes128=$(source ${LSF_SUITE_TOP}/ext/profile.platform; ${LSF_SUITE_PERF_BIN}/encryptTool.sh "${db_password}")
    # Change the username password in the Datasource definition
    sed -i "s|UserName=\".*\"|UserName=\"${db_user_aes128}\"|" ${LSF_SUITE_PERF_CONF}/datasource.xml
    sed -i "s|Password=\".*\"|Password=\"${db_password_aes128}\"|" ${LSF_SUITE_PERF_CONF}/datasource.xml
}

# Local variable declaration
logfile="/tmp/user_data.log"
default_cluster_name="HPCCluster"
login_hostname="${cluster_prefix}-login-001"
login_ip_address=${login_ip_address}
nfs_server_with_mount_path=${mount_path}
HostIP=$(hostname -I | awk '{print $1}')
HostName=$(hostname)
enable_ldap="${enable_ldap}"
ldap_server_ip="${ldap_server_ip}"
base_dn="${ldap_basedns}"
ManagementHostName="${HostName}"
ManagementHostNames=""
for (( i=1; i<=management_node_count; i++ ))
do
  ManagementHostNames+=" ${cluster_prefix}-mgmt-$i-001"
done
# Space at the beginning of the list must be removed, otherwise the Application Center WEBUI doesn't work
# properly in HA. In fact, if LSF_ADDON_HOSTS property has the list of the nodes with a space at the beginning
# the PAC - LSF interaction has issues.
ManagementHostNames=${ManagementHostNames# }
LSF_TOP="/opt/ibm/lsf"
LSF_CONF=$LSF_TOP/conf
LSF_SSH=$LSF_TOP/ssh
LSF_CONF_FILE=$LSF_CONF/lsf.conf
LSF_HOSTS_FILE=$LSF_CONF/hosts
LSF_EGO_CONF_FILE=$LSF_CONF/ego/$cluster_name/kernel/ego.conf
LSF_LSBATCH_CONF="$LSF_CONF/lsbatch/$cluster_name/configdir"
LSF_RC_CONF=$LSF_CONF/resource_connector
LSF_RC_IC_CONF=$LSF_RC_CONF/ibmcloudgen2/conf
LSF_DM_STAGING_AREA=$LSF_TOP/das_staging_area
# Should be changed in the upcoming days. Since the LSF core team have mismatched the path and we have approached to make the changes.
LSF_RC_IBMCLOUDHPC_CONF=$LSF_RC_CONF/ibmcloudhpc/conf
LSF_TOP_VERSION=$LSF_TOP/10.1

mkdir -p $LSF_RC_IBMCLOUDHPC_CONF
chown -R lsfadmin:root $LSF_RC_IBMCLOUDHPC_CONF

# Setup logs for user data
echo "START $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile

# Disallow root login
sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please login as the user \\\\\"lsfadmin or vpcuser\\\\\" rather than the user \\\\\"root\\\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys

# Setup Network configuration
# Change the MTU setting as this is required for setting mtu as 9000 for communication to happen between clusters
echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
echo "DOMAIN=\"$dns_domain\"" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"

# Change the MTU setting as 9000 at router level.
gateway_ip=$(ip route | grep default | awk '{print $3}' | head -n 1)
echo "${rc_cidr_block} via $gateway_ip dev ${network_interface} metric 0 mtu 9000" >> /etc/sysconfig/network-scripts/route-eth0

systemctl restart NetworkManager

echo 1 > /proc/sys/vm/overcommit_memory # tt reports many failures of memory allocation at fork(). why?
echo 'vm.overcommit_memory=1' > /etc/sysctl.conf
echo 'net.core.rmem_max=26214400' >> /etc/sysctl.conf
echo 'net.core.rmem_default=26214400' >> /etc/sysctl.conf
echo 'net.core.wmem_max=26214400' >> /etc/sysctl.conf
echo 'net.core.wmem_default=26214400' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_fin_timeout = 5' >> /etc/sysctl.conf
echo 'net.core.somaxconn = 8000' >> /etc/sysctl.conf
sudo sysctl -p /etc/sysctl.conf

# Setup the LSF
# 0. Update LSF configuration with new cluster name if cluster_name is not default
if [ "$default_cluster_name" != "$cluster_name" ]; then
  echo "New cluster name $cluster_name has been identified. Upgrading the cluster configurations accordingly" >> $logfile
  grep -rli "$default_cluster_name" $LSF_CONF/* | xargs sed -i "s/$default_cluster_name/$cluster_name/g" >> $logfile
  # Below directory in work has cluster_name twice in path and was resulting in a indefinite loop scenario. So, this directory has to be handled separately
  mv /opt/ibm/lsf/work/$default_cluster_name/live_confdir/lsbatch/$default_cluster_name /opt/ibm/lsf/work/"$cluster_name"/live_confdir/lsbatch/"$cluster_name" >> $logfile
  for file in $(find $LSF_TOP -name "*$default_cluster_name*"); do mv "$file" $(echo "$file"| sed -r "s/$default_cluster_name/$cluster_name/g"); done
fi

# 1. setting up lsf configuration
cat <<EOT >> $LSF_CONF_FILE
LSB_RC_EXTERNAL_HOST_IDLE_TIME=10
LSF_DYNAMIC_HOST_TIMEOUT="EXPIRY[10m] THRESHOLD[250] INTERVAL[60m]"
LSB_RC_EXTERNAL_HOST_FLAG="icgen2host cloudhpchost"
LSB_RC_UPDATE_INTERVAL=15
LSB_RC_MAX_NEWDEMAND=50
LSF_UDP_TO_TCP_THRESHOLD=9000
LSF_CALL_LIM_WITH_TCP=N
LSF_ANNOUNCE_MASTER_TCP_WAITTIME=600
LSF_RSH="ssh -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no'"
EOT
sed -i "s/LSF_MASTER_LIST=.*/LSF_MASTER_LIST=\"${ManagementHostNames}\"/g" $LSF_CONF_FILE

# Update the Job directory
sed -i 's|<Path>/home</Path>|<Path>/mnt/data</Path>|' /opt/ibm/lsfsuite/ext/gui/conf/Repository.xml

if [ "$hyperthreading" == true ]; then
  ego_define_ncpus="threads"
else
  ego_define_ncpus="cores"
  for vcpu in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq); do
    echo 0 > /sys/devices/system/cpu/cpu"$vcpu"/online
  done
fi
echo "EGO_DEFINE_NCPUS=${ego_define_ncpus}" >> $LSF_CONF_FILE

# 2. setting up lsf.shared
sed -i "s/^#  icgen2host/   icgen2host/g" $LSF_CONF/lsf.shared
sed -i '/^End Resource/i cloudhpchost  Boolean ()       ()         (hpc hosts from IBM Cloud HPC pool)' $LSF_CONF/lsf.shared

# 3. setting up lsb.module
sed -i "s/^#schmod_demand/schmod_demand/g" "$LSF_LSBATCH_CONF/lsb.modules"

# 4. setting up lsb.queue
sed -i '/^Begin Queue$/,/^End Queue$/{/QUEUE_NAME/{N;s/\(QUEUE_NAME\s*=[^\n]*\)\n/\1\nRC_HOSTS     = all\n/}}' "$LSF_LSBATCH_CONF/lsb.queues"
cat <<EOT >> "$LSF_LSBATCH_CONF/lsb.queues"
Begin Queue
QUEUE_NAME=das_q
DATA_TRANSFER=Y
RC_HOSTS=all
HOSTS=all
RES_REQ=type==any
End Queue
EOT

# 5. setting up lsb.hosts
for hostname in $ManagementHostNames; do
  sed -i "/^default    !.*/a $hostname  0 () () () () () (Y)" "$LSF_LSBATCH_CONF/lsb.hosts"
done

# 6. setting up lsf.cluster."$cluster_name"
sed -i "s/^lsfservers/#lsfservers/g" "$LSF_CONF/lsf.cluster.$cluster_name"
for hostname in $ManagementHostNames; do
  sed -i "/^#lsfservers.*/a $hostname ! ! 1 (mg)" "$LSF_CONF/lsf.cluster.$cluster_name"
done

# Updating the value of login node as Intel for lsfserver to update cluster file name
sed -i "/^#lsfservers.*/a $login_hostname Intel_E5 X86_64 0 ()" "$LSF_CONF/lsf.cluster.$cluster_name"
echo "LSF_SERVER_HOSTS=\"$ManagementHostNames\"" >> $LSF_CONF_FILE

# Update ego.conf
sed -i "s/EGO_MASTER_LIST=.*/EGO_MASTER_LIST=\"${ManagementHostNames}\"/g" "$LSF_EGO_CONF_FILE"
# 0.5 Update lsfservers with newly added lsf management nodes
grep -rli 'lsfservers' $LSF_CONF/*|xargs sed -i "s/lsfservers/${ManagementHostName}/g"

# Setup LSF resource connector
# 1. Create hostProviders.json
cat <<EOT > "$LSF_RC_CONF"/hostProviders.json
{
    "providers":[
        {
            "name": "ibmcloudhpc",
            "type": "ibmcloudhpcProv",
            "confPath": "resource_connector/ibmcloudhpc",
            "scriptPath": "resource_connector/ibmcloudhpc"
        }
    ]
}
EOT

# 2. Create ibmcloudgen2_config.json
cat <<EOT > "$LSF_RC_IC_CONF"/ibmcloudgen2_config.json
{
  "IBMCLOUDGEN2_KEY_FILE": "${LSF_RC_IC_CONF}/credentials",
  "IBMCLOUDGEN2_PROVISION_FILE": "${LSF_RC_IC_CONF}/user_data.sh",
  "IBMCLOUDGEN2_MACHINE_PREFIX": "${cluster_prefix}",
  "LogLevel": "INFO",
  "ApiEndPoints": {
    "us-east": "${api_endpoint_us_east}",
    "eu-de": "${api_endpoint_eu_de}"
  }
}
EOT

# 3. Create ibmcloudhpc_config.json
cat <<EOT > "$LSF_RC_IBMCLOUDHPC_CONF"/ibmcloudhpc_config.json
{
    "IBMCLOUDHPC_KEY_FILE": "${LSF_RC_IBMCLOUDHPC_CONF}/credentials",
    "IBMCLOUDHPC_PROVISION_FILE": "${LSF_RC_IBMCLOUDHPC_CONF}/user_data.sh",
    "IBMCLOUDHPC_MACHINE_PREFIX": "${cluster_prefix}",
    "LogLevel": "INFO",
    "CONTRACT_ID": "${contract_id}",
    "CLUSTER_ID": "${cluster_name}",
    "ApiEndPoints": {
        "us-east": "${api_endpoint_us_east}",
        "eu-de": "${api_endpoint_eu_de}"
    }
}
EOT

# 4. Create credentials for ibmcloudgen2
cat <<EOT > "$LSF_RC_IC_CONF"/credentials
# BEGIN ANSIBLE MANAGED BLOCK
VPC_URL=http://vpc.cloud.ibm.com/v1
VPC_AUTH_TYPE=iam
VPC_APIKEY=$VPC_APIKEY_VALUE
RESOURCE_RECORDS_URL=https://api.dns-svcs.cloud.ibm.com/v1
RESOURCE_RECORDS_AUTH_TYPE=iam
RESOURCE_RECORDS_APIKEY=$VPC_APIKEY_VALUE
EOT

# 5. Create credentials for ibmcloudhpc
cat <<EOT > "$LSF_RC_IBMCLOUDHPC_CONF"/credentials
# BEGIN ANSIBLE MANAGED BLOCK
CLOUD_HPC_URL=http://vpc.cloud.ibm.com/v1
CLOUD_HPC_AUTH_TYPE=iam
CLOUD_HPC_AUTH_URL=https://iam.cloud.ibm.com
CLOUD_HPC_APIKEY=$VPC_APIKEY_VALUE
RESOURCE_RECORDS_URL=https://api.dns-svcs.cloud.ibm.com/v1
RESOURCE_RECORDS_AUTH_TYPE=iam
RESOURCE_RECORDS_APIKEY=$VPC_APIKEY_VALUE
# END ANSIBLE MANAGED BLOCK
EOT

# 6. Create ibmcloudgen2_templates.json
cat <<EOT > "$LSF_RC_IC_CONF"/ibmcloudgen2_templates.json
{
    "templates": [
        {
            "templateId": "Template-${cluster_name}-1",
            "maxNumber": 0,
            "attributes": {
                "type": ["String", "X86_64"],
                "ncores": ["Numeric", "0"],
                "ncpus": ["Numeric", "0"],
                "mem": ["Numeric", "0"],
                "icgen2host": ["Boolean", "1"]
            },
            "imageId": "${imageID}",
            "subnetId": "${subnetID}",
            "vpcId": "${vpcID}",
            "vmType": "0",
            "securityGroupIds": ["${securityGroupID}"],
            "resourceGroupId": "${rc_rg}",
            "sshkey_id": "${sshkey_ID}",
            "region": "${regionName}",
            "zone": "${zoneName}"
        },
        {
            "templateId": "Template-${cluster_name}-2",
            "maxNumber": 0,
            "attributes": {
                "type": ["String", "X86_64"],
                "ncores": ["Numeric", "0"],
                "ncpus": ["Numeric", "0"],
                "mem": ["Numeric", "0"],
                "icgen2host": ["Boolean", "1"]
            },
            "imageId": "${imageID}",
            "subnetId": "${subnetID_2}",
            "vpcId": "${vpcID}",
            "vmType": "0",
            "securityGroupIds": ["${securityGroupID}"],
            "resourceGroupId": "${rc_rg}",
            "sshkey_id": "${sshkey_ID}",
            "region": "${regionName}",
            "zone": "${zoneName_2}"
        }
    ]
}
EOT

# 7. Create resource template for ibmcloudhc templates
ibmcloudhpc_templates="$LSF_RC_IBMCLOUDHPC_CONF/ibmcloudhpc_templates.json"
# Initialize an empty array to hold the JSON objects
json_array=()
counter=1
for i in 2 4 8 16 32 48 64 96 128; do
    templateId="Template-${cluster_prefix}-$counter"
    counter=$((counter + 1))
    vpcus=$i
    ncores=$((i / 2))
    if $hyperthreading; then
        ncpus=$vpcus
    else
        ncpus=$ncores
    fi
    maxmem=$((ncores * 16 * 1024))
    mem=$((maxmem * 9 / 10))
    json_object=$(cat <<EOF
{
  "templateId": "$templateId",
  "maxNumber": 500,
  "attributes": {
    "type": ["String", "X86_64"],
    "ncores": ["Numeric", "$ncores"],
    "ncpus": ["Numeric", "$ncpus"],
    "mem": ["Numeric", "$mem"],
    "maxmem": ["Numeric", "$maxmem"],
    "cloudhpchost": ["Boolean", "1"]
  },
  "imageId": "${imageID}",
  "vpcId": "${vpcID}",
  "region": "${regionName}",
  "priority": 10,
  "ibmcloudhpc_fleetconfig": "ibmcloudhpc_fleetconfig.json"
}
EOF
)
  if [[ $i -ne 128 ]]; then
    json_object="${json_object},"
  fi
  json_array+=("$json_object")
done
# Combine the JSON objects into a JSON array
json_data="{\"templates\": [${json_array[*]}]}"
# Write the JSON data to the output file
echo "$json_data" > "$ibmcloudhpc_templates"
echo "JSON templates are created and updated on ibmcloudhpc_templates.json" >> $logfile


#7 ibmcloudfleet_config.json
cat <<EOT > "$LSF_RC_IBMCLOUDHPC_CONF"/ibmcloudhpc_fleetconfig.json
{
    "fleet_request": {
        "availability_policy": {
            "host_failure": "restart"
        },
        "host_name": {
            "prefix": "${cluster_prefix}",
            "domain": "${dns_domain}"
        },
        "instance_selection": {
            "type": "automatic",
            "optimization": "minimum_price"
        },
        "boot_volume_attachment": {
          "encryption_key": {
            "crn": "${bootdrive_crn}"
          }
        },
        "zones": [
            {
                "name": "${zoneName}",
                "primary_network_interface": {
                    "name": "eth0",
                    "subnet": {
                        "crn": "${subnetID}"
                    },
                    "security_groups": [
                        {
                            "id": "${securityGroupID}"
                        }
                    ]
                }
            },
            {
                "name": "${zoneName_2}",
                "primary_network_interface": {
                    "name": "eth0",
                    "subnet": {
                        "crn": "${subnetID_2}"
                    },
                    "security_groups": [
                        {
                            "id": "${securityGroupID}"
                        }
                    ]
                }
            }
        ],
        "profile_requirement": {
            "families": [
                {
                    "name": "mx2",
                    "rank": 1,
                    "profiles": []
                }
            ]
        }
    }
}
EOT


# 8. create user_data.json for compute nodes
cat <<EOT > "$LSF_RC_IBMCLOUDHPC_CONF"/user_data.sh
#!/bin/bash
# Initialize variables
logfile=/tmp/user_data.log
cluster_prefix="${cluster_prefix}"
rc_cidr_block="${rc_cidr_block}"
rc_cidr_block_2="${rc_cidr_block_2}"
network_interface="${network_interface}"
dns_domain="${dns_domain}"
ManagementHostNames="${ManagementHostNames}"
lsf_public_key="${cluster_public_key_content}"
hyperthreading=${hyperthreading}
nfs_server_with_mount_path="${nfs_server_with_mount_path}"
custom_file_shares="${custom_file_shares}"
custom_mount_paths="${custom_mount_paths}"
enable_ldap="${enable_ldap}"
ldap_server_ip="${ldap_server_ip}"
base_dn="${ldap_basedns}"

# Disallow root login
sed -i -e "s/^/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"echo \'Please login as the user \\\\\"lsfadmin or vpcuser\\\\\" rather than the user \\\\\"root\\\\\".\';echo;sleep 5; exit 142\" /" /root/.ssh/authorized_keys

# Updates the lsfadmin user as never expire
chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin

# Setup Hostname
HostIP=\$(hostname -I | awk '{print \$1}')
hostname=\${cluster_prefix}-\${HostIP//./-}
hostnamectl set-hostname \$hostname

echo "START \$(date '+%Y-%m-%d %H:%M:%S')" >> \$logfile
# TODO: Usage of EXPORT_USER_DATA
%EXPORT_USER_DATA%

# Setup Network configuration
# Change the MTU setting as this is required for setting mtu as 9000 for communication to happen between clusters
if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then
    # Replace the MTU value in the Netplan configuration
    echo "MTU=9000" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
    echo "DOMAIN=\"${dns_domain}\"" >> "/etc/sysconfig/network-scripts/ifcfg-${network_interface}"
    # Change the MTU setting as 9000 at router level.
    gateway_ip=\$(ip route | grep default | awk '{print \$3}' | head -n 1)
    cidr_range=\$(ip route show | grep "kernel" | awk '{print \$1}' | head -n 1)
    echo "\$cidr_range via \$gateway_ip dev ${network_interface} metric 0 mtu 9000" >> /etc/sysconfig/network-scripts/route-eth0
    # Restart the Network Manager.
    systemctl restart NetworkManager
elif grep -q "NAME=\"Ubuntu\"" /etc/os-release; then
    net_int=\$(basename /sys/class/net/en*)
    netplan_config="/etc/netplan/50-cloud-init.yaml"
    gateway_ip=\$(ip route | grep default | awk '{print \$3}' | head -n 1)
    cidr_range=\$(ip route show | grep "kernel" | awk '{print \$1}' | head -n 1)
    usermod -s /bin/bash lsfadmin
    # Replace the MTU value in the Netplan configuration
    if ! grep -qE "^[[:space:]]*mtu: 9000" \$netplan_config; then
        echo "MTU 9000 Packages entries not found"
        # Append the MTU configuration to the Netplan file
        sudo sed -i '/'\$net_int':/a\            mtu: 9000' \$netplan_config
        sudo sed -i "/dhcp4: true/a \            nameservers:\n              search: [\$dns_domain]" \$netplan_config
        sudo sed -i '/'\$net_int':/a\            routes:\n              - to: '\$cidr_range'\n                via: '\$gateway_ip'\n                metric: 100\n                mtu: 9000' \$netplan_config
        sudo netplan apply
        echo "MTU set to 9000 on Netplan."
    else
        echo "MTU entry already exists in Netplan. Skipping."
    fi
fi

# TODO: Conditional NFS mount
LSF_TOP="/opt/ibm/lsf"
# Setup file share
if [ -n "\${nfs_server_with_mount_path}" ]; then
  echo "File share \${nfs_server_with_mount_path} found" >> \$logfile
  nfs_client_mount_path="/mnt/lsf"
  rm -rf "\${nfs_client_mount_path}"
  mkdir -p "\${nfs_client_mount_path}"
  # Mount LSF TOP
  mount -t nfs4 -o sec=sys,vers=4.1 "\$nfs_server_with_mount_path" "\$nfs_client_mount_path" >> \$logfile
  # Verify mount
  if mount | grep "\$nfs_client_mount_path"; then
    echo "Mount found" >> \$logfile
  else
    echo "No mount found, exiting!" >> \$logfile
    exit 1
  fi
  # Update mount to fstab for automount
  echo "\$nfs_server_with_mount_path \$nfs_client_mount_path nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
  for dir in conf work das_staging_area; do
    rm -rf "\${LSF_TOP}/\$dir"
    ln -fs "\${nfs_client_mount_path}/\$dir" "\${LSF_TOP}"
    chown -R lsfadmin:root "\${LSF_TOP}"
  done
fi
echo "Setting LSF share is completed." >> \$logfile

# Setup Custom file shares
echo "Setting custom file shares." >> \$logfile
# Setup file share
if [ -n "\${custom_file_shares}" ]; then
  echo "Custom file share \${custom_file_shares} found" >> \$logfile
  file_share_array=(\${custom_file_shares})
  mount_path_array=(\${custom_mount_paths})
  length=\${#file_share_array[@]}
  for (( i=0; i<length; i++ ))
  do
    rm -rf "\${mount_path_array[\$i]}"
    mkdir -p "\${mount_path_array[\$i]}"
    # Mount LSF TOP
    mount -t nfs4 -o sec=sys,vers=4.1 "\${file_share_array[\$i]}" "\${mount_path_array[\$i]}" >> \$logfile
    # Verify mount
    if mount | grep "\${file_share_array[\$i]}"; then
      echo "Mount found" >> \$logfile
    else
      echo "No mount found" >> \$logfile
    fi
    # Update permission to 777 for all users to access
    chmod 777 \${mount_path_array[\$i]}
    # Update mount to fstab for automount
    echo "\${file_share_array[\$i]} \${mount_path_array[\$i]} nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
  done
fi
echo "Setting custom file shares is completed." >> \$logfile

# Setup LSF environment variables
LSF_TOP="/opt/ibm/lsf_worker"
LSF_TOP_VERSION=10.1
LSF_CONF=\$LSF_TOP/conf
LSF_CONF_FILE=\$LSF_CONF/lsf.conf
. \$LSF_CONF/profile.lsf
echo "Logging env variables" >> \$logfile
env >> \$logfile

# Defining ncpus based on hyper-threading
if [ "\$hyperthreading" == true ]; then
  ego_define_ncpus="threads"
else
  ego_define_ncpus="cores"
  for vcpu in \$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq); do
    echo 0 > /sys/devices/system/cpu/cpu"\$vcpu"/online
  done
fi
echo "EGO_DEFINE_NCPUS=\${ego_define_ncpus}" >> \$LSF_CONF_FILE

# Update lsf configuration
echo 'LSB_MC_DISABLE_HOST_LOOKUP=Y' >> \$LSF_CONF_FILE
echo "LSF_RSH=\"ssh -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no'\"" >> \$LSF_CONF_FILE
sed -i "s/LSF_SERVER_HOSTS=.*/LSF_SERVER_HOSTS=\"\$ManagementHostNames\"/g" \$LSF_CONF_FILE

# TODO: Understand usage
# Support rc_account resource to enable RC_ACCOUNT policy
if [ -n "\${rc_account}" ]; then
sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap \${rc_account}*rc_account]\"/" \$LSF_CONF_FILE
echo "Update LSF_LOCAL_RESOURCES lsf.conf successfully, add [resourcemap \${rc_account}*rc_account]" >> \$logfile
fi
# Add additional local resources if needed
instance_id=\$(dmidecode | grep Family | cut -d ' ' -f 2 |head -1)
if [ -n "\$instance_id" ]; then
  sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap \$instance_id*instanceID]\"/" \$LSF_CONF_FILE
  echo "Update LSF_LOCAL_RESOURCES in \$LSF_CONF_FILE successfully, add [resourcemap \${instance_id}*instanceID]" >> \$logfile
else
  echo "Can not get instance ID" >> \$logfile
fi

#Update LSF Tuning on dynamic hosts
LSF_TUNABLES="etc/sysctl.conf"
echo 'vm.overcommit_memory=1' >> \$LSF_TUNABLES
echo 'net.core.rmem_max=26214400' >> \$LSF_TUNABLES
echo 'net.core.rmem_default=26214400' >> \$LSF_TUNABLES
echo 'net.core.wmem_max=26214400' >> \$LSF_TUNABLES
echo 'net.core.wmem_default=26214400' >> \$LSF_TUNABLES
echo 'net.ipv4.tcp_fin_timeout = 5' >> \$LSF_TUNABLES
echo 'net.core.somaxconn = 8000' >> \$LSF_TUNABLES
sudo sysctl -p \$LSF_TUNABLES

# Setup ssh
lsfadmin_home_dir="/home/lsfadmin"
lsfadmin_ssh_dir="\${lsfadmin_home_dir}/.ssh"
mkdir -p \$lsfadmin_ssh_dir
if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then
  cp /home/vpcuser/.ssh/authorized_keys \$lsfadmin_ssh_dir/authorized_keys
else
  cp /home/ubuntu/.ssh/authorized_keys "${lsfadmin_ssh_dir}/authorized_keys"
  sudo cp /home/ubuntu/.profile \$lsfadmin_home_dir
fi
echo "\${lsf_public_key}" >> \$lsfadmin_ssh_dir/authorized_keys
echo "StrictHostKeyChecking no" >> \$lsfadmin_ssh_dir/config
chmod 600 \$lsfadmin_ssh_dir/authorized_keys
chmod 700 \$lsfadmin_ssh_dir
chown -R lsfadmin:lsfadmin \$lsfadmin_ssh_dir
echo "SSH key setup for lsfadmin user is completed" >> \$logfile
echo "source \${LSF_CONF}/profile.lsf" >> \$lsfadmin_home_dir/.bashrc
echo "source /opt/intel/oneapi/setvars.sh >> /dev/null" >> \$lsfadmin_home_dir/.bashrc
echo "Setting up LSF env variables for lasfadmin user is completed" >> \$logfile

# Create lsf.sudoers file to support single lsfstartup and lsfrestart command from management node
echo 'LSF_STARTUP_USERS="lsfadmin"' | sudo tee -a /etc/lsf1.sudoers
echo "LSF_STARTUP_PATH=\$LSF_TOP_VERSION/linux3.10-glibc2.17-x86_64/etc/" | sudo tee -a /etc/lsf.sudoers
chmod 600 /etc/lsf.sudoers
ls -l /etc/lsf.sudoers
sudo /opt/ibm/lsf/10.1/install/hostsetup --top="/opt/ibm/lsf_worker/" --setuid
echo "Added LSF administrators to start LSF daemons" >> $logfile

cat /opt/ibm/lsf/conf/hosts >> /etc/hosts

# Setting up the LDAP configuration
if [ "\$enable_ldap" = "true" ]; then

    # Detect the operating system
    if grep -q "NAME=\"Red Hat Enterprise Linux\"" /etc/os-release; then

        # Detect RHEL version
        rhel_version=\$(grep -oE 'release [0-9]+' /etc/redhat-release | awk '{print \$2}')

        if [ "\$rhel_version" == "8" ]; then
            echo "Detected RHEL 8. Proceeding with LDAP client configuration...." >> "\$logfile"

            # Allow Password authentication
            sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
            systemctl restart sshd

            # Configure LDAP authentication
            authconfig --enableldap --enableldapauth \
                        --ldapserver=ldap://\${ldap_server_ip} \
                        --ldapbasedn="dc=\${base_dn%%.*},dc=\${base_dn#*.}" \
                        --enablemkhomedir --update

            # Check the exit status of the authconfig command
            if [ \$? -eq 0 ]; then
                echo "LDAP Authentication enabled successfully." >> "\$logfile"
            else
                echo "Failed to enable LDAP and LDAP Authentication." >> "\$logfile"
                exit 1
            fi

            # Update LDAP Client configurations in nsswitch.conf
            sed -i -e 's/^passwd:.*\$/passwd: files ldap/' \
                -e 's/^shadow:.*\$/shadow: files ldap/' \
                -e 's/^group:.*\$/group: files ldap/' /etc/nsswitch.conf

            # Update PAM configuration files
            sed -i -e '/^auth/d' /etc/pam.d/password-auth
            sed -i -e '/^auth/d' /etc/pam.d/system-auth

            auth_line="\nauth        required      pam_env.so\n\
auth        sufficient    pam_unix.so nullok try_first_pass\n\
auth        requisite     pam_succeed_if.so uid >= 1000 quiet_success\n\
auth        sufficient    pam_ldap.so use_first_pass\n\
auth        required      pam_deny.so"

            echo -e "\$auth_line" | tee -a /etc/pam.d/password-auth /etc/pam.d/system-auth

            # Copy 'password-auth' settings to 'sshd'
            cat /etc/pam.d/password-auth > /etc/pam.d/sshd

            # Configure nslcd
            cat <<EOF > /etc/nslcd.conf
uid nslcd
gid ldap
uri ldap://\${ldap_server_ip}/
base dc=\${base_dn%%.*},dc=\${base_dn#*.}
EOF

            # Restart nslcd and nscd service
            systemctl restart nslcd
            systemctl restart nscd

            # Validate the LDAP configuration
            if ldapsearch -x -H ldap://\${ldap_server_ip}/ -b "dc=\${base_dn%%.*},dc=\${base_dn#*.}" > /dev/null; then
                echo "LDAP configuration completed successfully !!" >> "\$logfile"
            else
                echo "LDAP configuration failed !!" >> "\$logfile"
                exit 1
            fi

            # Make LSF commands available for every user.
            echo ". \${LSF_CONF}/profile.lsf" >> /etc/bashrc
            source /etc/bashrc
        else
            echo "This script is designed for RHEL 8. Detected RHEL version: \$rhel_version. Exiting." >> "\$logfile"
            exit 1
        fi

    elif grep -q "NAME=\"Ubuntu\"" /etc/os-release; then

        echo "Detected as Ubuntu. Proceeding with LDAP client configuration..." >> \$logfile

        # Update package repositories
        sudo apt update -y

        # Required LDAP client packages
        export UTILITYS="ldap-utils libpam-ldap libnss-ldap nscd nslcd"

        # Update SSH configuration to allow password authentication
        sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
        sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/50-cloudimg-settings.conf
        sudo systemctl restart ssh

        # Create preseed file for LDAP configuration
        cat > debconf-ldap-preseed.txt <<EOF
ldap-auth-config    ldap-auth-config/ldapns/ldap-server    string    \${ldap_server_ip}
ldap-auth-config    ldap-auth-config/ldapns/base-dn    string     dc=\${base_dn%%.*},dc=\${base_dn#*.}
ldap-auth-config    ldap-auth-config/ldapns/ldap_version    select    3
ldap-auth-config    ldap-auth-config/dbrootlogin    boolean    false
ldap-auth-config    ldap-auth-config/dblogin    boolean    false
nslcd   nslcd/ldap-uris string  \${ldap_server_ip}
nslcd   nslcd/ldap-base string  dc=\${base_dn%%.*},dc=\${base_dn#*.}
EOF

        # Check if the preseed file exists
        if [ -f debconf-ldap-preseed.txt ]; then

            # Apply preseed selections
            cat debconf-ldap-preseed.txt | debconf-set-selections

            # Install LDAP client packages
            sudo apt-get install -y \${UTILITYS}

            sleep 2

            # Add session configuration to create home directories
            sudo sed -i '\$ i\session required pam_mkhomedir.so skel=/etc/skel umask=0022\' /etc/pam.d/common-session

            # Update nsswitch.conf
            sudo sed -i 's/^passwd:.*\$/passwd: compat systemd ldap/' /etc/nsswitch.conf
            sudo sed -i 's/^group:.*\$/group: compat systemd ldap/' /etc/nsswitch.conf
            sudo sed -i 's/^shadow:.*\$/shadow: compat/' /etc/nsswitch.conf

            # Update common-password PAM configuration
            sudo sed -i 's/pam_ldap.so use_authtok/pam_ldap.so/' /etc/pam.d/common-password

            # Make LSF commands available for every user.
            echo ". \${LSF_CONF}/profile.lsf" >> /etc/bash.bashrc
            source /etc/bash.bashrc

            # Restart nslcd and nscd service
            systemctl restart nslcd
            systemctl restart nscd

            # Enable nslcd and nscd service
            systemctl enable nslcd
            systemctl enable nscd

            # Validate the LDAP client service status
            if sudo systemctl is-active --quiet nscd; then
                echo "LDAP client configuration completed successfully !!"
            else
                echo "LDAP client configuration failed. nscd service is not running."
                exit 1
            fi
        else
            echo -e "debconf-ldap-preseed.txt Not found. Skipping LDAP client configuration."
        fi
    else
        echo "This script is designed for Ubuntu 22, and installation is not supported. Exiting." >> "\$logfile"
    fi
fi


#update lsf client ip address to LSF_HOSTS_FILE
echo $login_ip_address   $login_hostname >> $LSF_HOSTS_FILE
# Startup lsf daemons
lsf_daemons start &
sleep 5
lsf_daemons status >> \$logfile
echo "END \$(date '+%Y-%m-%d %H:%M:%S')" >> \$logfile
EOT

# TODO: Setting up License Scheduler configurations
# No changes has been advised to be automated

# 8 . Copy user_data.sh from ibmcloudhpc to ibmcloudgen2
cp $LSF_RC_IBMCLOUDHPC_CONF/user_data.sh $LSF_RC_IC_CONF/user_data.sh

# Setting up Data Manager configurations
mkdir -p "${LSF_DM_STAGING_AREA}"
chown -R lsfadmin:root "${LSF_DM_STAGING_AREA}"
cat <<EOT >> "${LSF_CONF}"/lsf.datamanager."${cluster_name}"
Begin Parameters
ADMINS = lsfadmin
STAGING_AREA = "${LSF_DM_STAGING_AREA}"
End Parameters
EOT

# Uncomment the below line to enable Datamanger
cat <<EOT >> $LSF_CONF_FILE
#LSF_DATA_HOSTS=${HostName}
# LSF_DATA_PORT=1729
EOT
echo "Setting LSF configuration is completed." >> $logfile

# Setup LSF
echo "Setting LSF share." >> $logfile
# Setup file share
if [ -n "${nfs_server_with_mount_path}" ]; then
  echo "File share ${nfs_server_with_mount_path} found" >> $logfile
  # Create a data directory for sharing HPC workload data
  mkdir -p "${LSF_TOP}/data"
  nfs_client_mount_path="/mnt/lsf"
  rm -rf "${nfs_client_mount_path}"
  mkdir -p "${nfs_client_mount_path}"
  # Mount LSF TOP
  mount -t nfs4 -o sec=sys,vers=4.1 "$nfs_server_with_mount_path" "$nfs_client_mount_path" >> $logfile
  # Verify mount
  if mount | grep "$nfs_client_mount_path"; then
    echo "Mount found" >> $logfile
  else
    echo "No mount found, exiting!" >> $logfile
    exit 1
  fi
  # Update mount to fstab for automount
  echo "$nfs_server_with_mount_path $nfs_client_mount_path nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
  for dir in conf work das_staging_area; do
    mv "${LSF_TOP}/$dir" "${nfs_client_mount_path}"
    ln -fs "${nfs_client_mount_path}/$dir" "${LSF_TOP}"
    chown -R lsfadmin:root "${LSF_TOP}"
  done
  #Create folder in shared file system to store logs
  mkdir -p "${nfs_client_mount_path}/log/${HOSTNAME}"
  chown -R lsfadmin:root "${nfs_client_mount_path}/log"
  #Move all existing logs to the new folder
  mv ${LSF_TOP}/log/* "${nfs_client_mount_path}/log/${HOSTNAME}"
  #Remove the original folder and create symlink so the user can still access to default location
  rm -rf "${LSF_TOP}/log"
  ln -fs "${nfs_client_mount_path}/log/${HOSTNAME}" "${LSF_TOP}/log"
  chown -R lsfadmin:root "${LSF_TOP}/log"
else
  echo "No mount point value found, exiting!" >> $logfile
  exit 1
fi
echo "Setting LSF share is completed." >> $logfile

# Setup Custom file shares
echo "Setting custom file shares." >> $logfile
# Setup file share
if [ -n "${custom_file_shares}" ]; then
  echo "Custom file share ${custom_file_shares} found" >> $logfile
  file_share_array=(${custom_file_shares})
  mount_path_array=(${custom_mount_paths})
  length=${#file_share_array[@]}
  for (( i=0; i<length; i++ ))
  do
    rm -rf "${mount_path_array[$i]}"
    mkdir -p "${mount_path_array[$i]}"
    # Mount LSF TOP
    mount -t nfs4 -o sec=sys,vers=4.1 "${file_share_array[$i]}" "${mount_path_array[$i]}" >> $logfile
    # Verify mount
    if mount | grep "${file_share_array[$i]}"; then
      echo "Mount found" >> $logfile
    else
      echo "No mount found" >> $logfile
    fi
    # Update permission to 777 for all users to access
    chmod 777 ${mount_path_array[$i]}
    # Update mount to fstab for automount
    echo "${file_share_array[$i]} ${mount_path_array[$i]} nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
  done
fi
echo "Setting custom file shares is completed." >> $logfile

# Startup lsf daemons
. $LSF_TOP/conf/profile.lsf
echo "Setting up LSF env is completed" >> $logfile
# Setup ip-host mapping in LSF_HOSTS_FILE
python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${cluster_prefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]) + '\n' + '\n'.join([str(ip) + ' ${cluster_prefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block_2}')]))" >> "$LSF_HOSTS_FILE"
# Update the entry  to LSF_HOSTS_FILE
sed -i "s/^$HostIP .*/$HostIP $HostName/g" $LSF_HOSTS_FILE
for hostname in $ManagementHostNames; do
  while ! grep "$hostname" "$LSF_HOSTS_FILE"; do
    echo "Waiting for $hostname to be added to LSF host file" >> $logfile
    sleep 5
  done
done
cat $LSF_HOSTS_FILE >> /etc/hosts
lsf_daemons start &
sleep 5
lsf_daemons status >> $logfile
echo "END $(date '+%Y-%m-%d %H:%M:%S')" >> $logfile

# Setup lsfadmin user
# Updates the lsfadmin user as never expire
chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin
# Setup ssh
lsfadmin_home_dir="/home/lsfadmin"
lsfadmin_ssh_dir="${lsfadmin_home_dir}/.ssh"
mkdir -p ${lsfadmin_ssh_dir}
cp /home/vpcuser/.ssh/authorized_keys "${lsfadmin_ssh_dir}/authorized_keys"
echo "${cluster_public_key_content}" >> "${lsfadmin_ssh_dir}/authorized_keys"
echo "${cluster_private_key_content}" >> "${lsfadmin_ssh_dir}/id_rsa"
echo "StrictHostKeyChecking no" >> "${lsfadmin_ssh_dir}/config"
chmod 600 "${lsfadmin_ssh_dir}/authorized_keys"
chmod 600 "${lsfadmin_ssh_dir}/id_rsa"
chmod 700 ${lsfadmin_ssh_dir}
chown -R lsfadmin:lsfadmin ${lsfadmin_ssh_dir}
echo "SSH key setup for lsfadmin user is completed" >> $logfile
echo "source ${LSF_CONF}/profile.lsf" >> "${lsfadmin_home_dir}"/.bashrc

# Setup root user
root_ssh_dir="/root/.ssh"
echo "${cluster_public_key_content}" >> $root_ssh_dir/authorized_keys
echo "StrictHostKeyChecking no" >> $root_ssh_dir/config
echo "cluster ssh key has been added to root user" >> $logfile
echo "source ${LSF_CONF}/profile.lsf" >> /root/.bashrc

# Create lsf.sudoers file to support single lsfstartup and lsfrestart command from management node
cat <<EOT > "/etc/lsf.sudoers"
LSF_STARTUP_USERS="lsfadmin"
LSF_STARTUP_PATH=$LSF_TOP_VERSION/linux3.10-glibc2.17-x86_64/etc/
EOT
chmod 600 /etc/lsf.sudoers
ls -l /etc/lsf.sudoers
sudo /opt/ibm/lsf/10.1/install/hostsetup --top="/opt/ibm/lsf/" --setuid
echo "Added LSF administrators to start LSF daemons" >> $logfile

# Setting up the Application Center
if [ "$enable_app_center" = true ] ;
then
      if rpm -q lsf-appcenter
    then
        echo "Application center packages are found..." >> $logfile
        echo ${app_center_gui_pwd} | sudo passwd --stdin lsfadmin
        sed -i '$i\\ALLOW_EVENT_TYPE=JOB_NEW JOB_STATUS JOB_FINISH2 JOB_START JOB_EXECUTE JOB_EXT_MSG JOB_SIGNAL JOB_REQUEUE JOB_MODIFY2 JOB_SWITCH METRIC_LOG' $LSF_ENVDIR/lsbatch/"$cluster_name"/configdir/lsb.params
        sed -i 's/NEWJOB_REFRESH=y/NEWJOB_REFRESH=Y/g' $LSF_ENVDIR/lsbatch/"$cluster_name"/configdir/lsb.params
        sed -i 's/NoVNCProxyHost=.*/NoVNCProxyHost=localhost/g' /opt/ibm/lsfsuite/ext/gui/conf/pmc.conf
        if [ "${enable_high_availability}" = true ]; then
            echo "LSF_ADDON_HOSTS=\"${ManagementHostNames}\"" >> $LSF_ENVDIR/lsf.conf
            create_certificate
            create_appcenter_database
            configure_icd_datasource
        else
            echo LSF_ADDON_HOSTS=$HOSTNAME >> $LSF_ENVDIR/lsf.conf
        fi
        echo 'source /opt/ibm/lsfsuite/ext/profile.platform' >> ~/.bashrc
        echo 'source /opt/ibm/lsfsuite/ext/profile.platform' >> "${lsfadmin_home_dir}"/.bashrc
        source ~/.bashrc
        sudo rm -rf /opt/ibm/lsfsuite/ext/gui/3.0/bin/novnc.pem
        # Restart the LSF Daemons to let LSF reload the configuration change
        lsf_daemons restart &
        sleep 5
        lsf_daemons status >> $logfile
        # Start all the PerfMonitor and WEBUI processes.
        perfadmin start all; sleep 5;  pmcadmin stop; sleep 160; pmcadmin start; sleep 5; pmcadmin list >> $logfile
        appcenter_status=$(pmcadmin list | grep "WEBGUI" | awk '{print $2}')
        if [ "$appcenter_status" = "STARTED" ]; then
            echo "Application Center installation completed..." >> $logfile
        else
            echo "Application Center installation failed..." >> $logfile
        fi
    fi
else
	  echo 'Application Center installation skipped...' >> $logfile
fi

# TODO: Understand how lsf should work after reboot, need better cron job
if [ "$enable_app_center" = "true" ]; then
    (crontab -l 2>/dev/null; echo "@reboot sleep 30 && source ~/.bashrc && lsf_daemons start && lsf_daemons status && perfadmin start all && sleep 5 && pmcadmin start") | crontab -;
else
    (crontab -l 2>/dev/null; echo "@reboot sleep 30 && source ~/.bashrc && lsf_daemons start && lsf_daemons status") | crontab -;
fi

# Setting up the LDAP configuration
if [ "$enable_ldap" = "true" ]; then

    # Detect RHEL version
    rhel_version=$(grep -oE 'release [0-9]+' /etc/redhat-release | awk '{print $2}')

    if [ "$rhel_version" == "8" ]; then
        echo "Detected RHEL 8. Proceeding with LDAP client configuration...." >> "$logfile"

        # Allow Password authentication
        sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
        systemctl restart sshd

        # Configure LDAP authentication
        authconfig --enableldap --enableldapauth \
                    --ldapserver=ldap://${ldap_server_ip} \
                    --ldapbasedn="dc=${base_dn%%.*},dc=${base_dn#*.}" \
                    --enablemkhomedir --update

        # Check the exit status of the authconfig command
        if [ $? -eq 0 ]; then
            echo "LDAP Authentication enabled successfully." >> "$logfile"
        else
            echo "Failed to enable LDAP and LDAP Authentication." >> "$logfile"
            exit 1
        fi

        # Update LDAP Client configurations in nsswitch.conf
        sed -i -e 's/^passwd:.*$/passwd: files ldap/' \
               -e 's/^shadow:.*$/shadow: files ldap/' \
               -e 's/^group:.*$/group: files ldap/' /etc/nsswitch.conf

        # Update PAM configuration files
        sed -i -e '/^auth/d' /etc/pam.d/password-auth
        sed -i -e '/^auth/d' /etc/pam.d/system-auth

        auth_line="\nauth        required      pam_env.so\n\
auth        sufficient    pam_unix.so nullok try_first_pass\n\
auth        requisite     pam_succeed_if.so uid >= 1000 quiet_success\n\
auth        sufficient    pam_ldap.so use_first_pass\n\
auth        required      pam_deny.so"

        echo -e "$auth_line" | tee -a /etc/pam.d/password-auth /etc/pam.d/system-auth

        # Copy 'password-auth' settings to 'sshd'
        cat /etc/pam.d/password-auth > /etc/pam.d/sshd

        # Configure nslcd
        cat <<EOF > /etc/nslcd.conf
uid nslcd
gid ldap
uri ldap://${ldap_server_ip}/
base dc=${base_dn%%.*},dc=${base_dn#*.}
EOF

        # Restart nslcd and nscd service
        systemctl restart nslcd
        systemctl restart nscd

        # Enable nslcd and nscd service
        systemctl enable nslcd
        systemctl enable nscd

        # Validate the LDAP configuration
        if ldapsearch -x -H ldap://${ldap_server_ip}/ -b "dc=${base_dn%%.*},dc=${base_dn#*.}" > /dev/null; then
            echo "LDAP configuration completed successfully !!" >> "$logfile"
        else
            echo "LDAP configuration failed !!" >> "$logfile"
            exit 1
        fi

        # Make LSF commands available for every user.
        echo ". ${LSF_CONF}/profile.lsf" >> /etc/bashrc
        source /etc/bashrc
    else
        echo "This script is designed for RHEL 8. Detected RHEL version: $rhel_version. Exiting." >> "$logfile"
        exit 1
    fi
fi
