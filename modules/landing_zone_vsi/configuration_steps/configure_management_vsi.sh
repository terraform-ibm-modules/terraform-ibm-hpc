#!/bin/bash
# shellcheck disable=all

###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

#set -x # uncomment with care: this can log too much, including credentials

# Setup logs
logfile="/tmp/configure_management.log"
exec > >(stdbuf -oL awk '{print strftime("%Y-%m-%dT%H:%M:%S") " " $0}' | tee "$logfile") 2>&1
# automatic logging of stdout and stderr, including timestamps; no need to redirect explicitly

echo "START $(date '+%Y-%m-%d %H:%M:%S')"

source management_values

# Local variable declaration
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
ManagementHostNamePrimary="${cluster_prefix}-mgmt-1-001"
ManagementHostNames=""
for (( i=1; i<=management_node_count; i++ )); do
  ManagementHostNames+=" ${cluster_prefix}-mgmt-$i-001"
done
# Space at the beginning of the list must be removed, otherwise the Application Center WEBUI doesn't work
# properly in HA. In fact, if LSF_ADDON_HOSTS property has the list of the nodes with a space at the beginning
# the PAC - LSF interaction has issues.
ManagementHostNames=${ManagementHostNames# }

LSF_TOP="/opt/ibm/lsf"
LSF_CONF="$LSF_TOP/conf"
LSF_SSH="$LSF_TOP/ssh"
LSF_CONF_FILE="$LSF_CONF/lsf.conf"
LSF_HOSTS_FILE="$LSF_CONF/hosts"
LSF_EGO_CONF_FILE="$LSF_CONF/ego/$cluster_name/kernel/ego.conf"
LSF_LSBATCH_CONF="$LSF_CONF/lsbatch/$cluster_name/configdir"
LSF_RC_CONF="$LSF_CONF/resource_connector"
LSF_RC_IC_CONF="$LSF_RC_CONF/ibmcloudgen2/conf"
LSF_DM_STAGING_AREA="$LSF_TOP/das_staging_area"
# Should be changed in the upcoming days. Since the LSF core team have mismatched the path and we have approached to make the changes.
LSF_RC_IBMCLOUDHPC_CONF="$LSF_RC_CONF/ibmcloudhpc/conf"
LSF_TOP_VERSION="$LSF_TOP/10.1"

# Useful variables that reference the main GUI and PERF Manager folders.
LSF_SUITE_TOP="/opt/ibm/lsfsuite"
LSF_SUITE_GUI="${LSF_SUITE_TOP}/ext/gui"
LSF_SUITE_GUI_CONF="${LSF_SUITE_GUI}/conf"
LSF_SUITE_PERF="${LSF_SUITE_TOP}/ext/perf"
LSF_SUITE_PERF_CONF="${LSF_SUITE_PERF}/conf"
LSF_SUITE_PERF_BIN="${LSF_SUITE_PERF}/1.2/bin"

# important: is this a primary or secondary management node?
if [ "$HostName" == "$ManagementHostNamePrimary" ]; then
  on_primary="true"
else
  on_primary="false"
fi
echo "is this node primary: $on_primary"

echo "umask=$(umask)"
umask 022 # since being run with 077 can cause issues
echo "umask=$(umask)"

db_certificate_file="${LSF_SUITE_GUI_CONF}/cert.pem"

# Function that dump the ICD certificate in the $db_certificate_file
create_certificate() {
    # Dump the CA certificate in the ${db_certificate_file} file and set permissions
    echo "${db_certificate}" | base64 -d > "${db_certificate_file}"
    chown lsfadmin:lsfadmin "${db_certificate_file}"
    chmod 644 "${db_certificate_file}"

}

# Function for creating PAC database in the IBM Cloud Database (ICD) service when High Availability is enabled.
# It is invoked when ${enable_app_center} and ${app_center_high_availability} are both true.
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

    # On ICD you cannot change system variables so we need to comment 736 line in $LSF_SUITE_GUI/DBschema/MySQL/create_pac_schema.sql
    sed -i "s|SET GLOBAL group_concat_max_len = 1000000;|/* SET GLOBAL group_concat_max_len = 1000000; */|" $LSF_SUITE_GUI/DBschema/MySQL/create_pac_schema.sql
    # Create the PAC database
    echo "${create_db_command}" | MYSQL_PWD="${db_adminpassword}" mysql --host="${db_hostname}" --port="${db_port}" --user="${db_adminuser}" --ssl-ca="${db_certificate_file}" ibmclouddb
    # Create the pacuser, grant him all the required privileges, then create the schema and tables
    for command in "${commands[@]}"; do
        echo "${command}" | MYSQL_PWD="${db_adminpassword}" mysql --host="${db_hostname}" --port="${db_port}" --user="${db_adminuser}" --ssl-ca="${db_certificate_file}" pac
    done
}

# Configures the GUI JDBC datasource file ${LSF_SUITE_PERF_CONF}/datasource.xml
# to reference the IBM Cloud Database (ICD) instance. If ${enable_app_center} and
# ${app_center_high_availability} are both true, updates the connection string to
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

########### LSFSETUP-BEGIN ################################################################
###################################### search LSFSETUP-END to skip this part ##############

# Setup LSF

if [ "$on_primary" == "true" ]; then

  echo "LSF configuration begin"

  mkdir -p $LSF_RC_IBMCLOUDHPC_CONF
  chown -R lsfadmin:root $LSF_RC_IBMCLOUDHPC_CONF

  echo "Setting up LSF"

  # 0. Update LSF configuration with new cluster name if cluster_name is not default
  if [ "$default_cluster_name" != "$cluster_name" ]; then
    echo "New cluster name $cluster_name has been identified. Upgrading the cluster configurations accordingly."
    grep -rli "$default_cluster_name" $LSF_CONF/* | xargs sed -i "s/$default_cluster_name/$cluster_name/g"
    # Below directory in work has cluster_name twice in path and was resulting in a indefinite loop scenario. So, this directory has to be handled separately
    mv $LSF_TOP/work/$default_cluster_name/live_confdir/lsbatch/$default_cluster_name $LSF_TOP/work/"$cluster_name"/live_confdir/lsbatch/"$cluster_name"
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
LSF_CLOUD_UI=Y
LSF_RSH="ssh -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no'"
EOT
  sed -i "s/LSF_MASTER_LIST=.*/LSF_MASTER_LIST=\"${ManagementHostNames}\"/g" $LSF_CONF_FILE

  if [ "$hyperthreading" == true ]; then
    ego_define_ncpus="threads"
  else
    ego_define_ncpus="cores"
  fi
  echo "EGO_DEFINE_NCPUS=${ego_define_ncpus}" >> $LSF_CONF_FILE

  # 2. setting up lsf.shared
  sed -i "s/^#  icgen2host/   icgen2host/g" $LSF_CONF/lsf.shared
  sed -i '/^End Resource/i cloudhpchost  Boolean ()       ()         (hpc hosts from IBM Cloud HPC pool)' $LSF_CONF/lsf.shared
  sed -i '/^End Resource/i family        String  ()       ()         (account name for the external hosts)' $LSF_CONF/lsf.shared

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
  sed -i 's/LSF_HOST_ADDR_RANGE=\*.\*.\*.\*/LSF_HOST_ADDR_RANGE=10.*.*.*/' "$LSF_CONF/lsf.cluster.$cluster_name"
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
  echo "Setting up LSF resource connector"

  # 1. Create hostProviders.json
  if [ "$regionName" = "eu-de" ] || [ "$regionName" = "us-east" ] || [ "$regionName" = "us-south" ] ; then
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
  else
    cat <<EOT > "$LSF_RC_CONF"/hostProviders.json
{
    "providers":[
        {
            "name": "ibmcloudgen2",
            "type": "ibmcloudgen2Prov",
            "confPath": "resource_connector/ibmcloudgen2",
            "scriptPath": "resource_connector/ibmcloudgen2"
        }
    ]
}
EOT
  fi

  # 2. Create ibmcloudgen2_config.json
  cat <<EOT > "$LSF_RC_IC_CONF"/ibmcloudgen2_config.json
{
  "IBMCLOUDGEN2_KEY_FILE": "${LSF_RC_IC_CONF}/credentials",
  "IBMCLOUDGEN2_PROVISION_FILE": "${LSF_RC_IC_CONF}/user_data.sh",
  "IBMCLOUDGEN2_MACHINE_PREFIX": "${cluster_prefix}",
  "LogLevel": "INFO",
  "ApiEndPoints": {
    "eu-gb": "https://eu-gb.iaas.cloud.ibm.com/v1",
    "au-syd": "https://au-syd.iaas.cloud.ibm.com/v1",
    "ca-tor": "https://ca-tor.iaas.cloud.ibm.com/v1",
    "jp-osa": "https://jp-osa.iaas.cloud.ibm.com/v1",
    "jp-tok": "https://jp-tok.iaas.cloud.ibm.com/v1",
    "br-sao": "https://br-sao.iaas.cloud.ibm.com/v1"
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
        "eu-de": "${api_endpoint_eu_de}",
        "us-south": "${api_endpoint_us_south}"
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
  ibmcloudgen2_templates="$LSF_RC_IC_CONF/ibmcloudgen2_templates.json"
  # Incrementally build a json string
  json_string=""

  tab="$(cat <<EOF
2   mx2-2x16
4   mx2-4x32
8   mx2-8x64
16  mx2-16x128
32  mx2-32x256
48  mx2-48x384
64  mx2-64x512
96  mx2-96x768
128 mx2-128x1024
EOF
)"

  # Loop over table entries
  while read i vmType; do
    # Construct JSON object
    for j in 1; do
      # Set template ID based on j
      if [ "$j" -eq 1 ]; then
        templateId="Template-$cluster_prefix-$((j*1000+i))"
        subnetId="${subnetID}"
        zone="${zoneName}"
      fi

      # Construct JSON object
      vpcus=$i
      ncores=$((i / 2))
      if $hyperthreading; then
          ncpus=$vpcus
      else
          ncpus=$ncores
      fi
      maxmem=$((ncores * 16 * 1024))
      mem=$((maxmem * 9 / 10))
      if [ "${imageID:0:4}" == "crn:" ]; then
        imagetype="imageCrn"
      else
        imagetype="imageId"
      fi
      json_string+=$(cat <<EOF
{
 "templateId": "$templateId",
 "maxNumber": "$rc_max_num",
 "attributes": {
  "type": ["String", "X86_64"],
  "ncores": ["Numeric", "$ncores"],
  "ncpus": ["Numeric", "$ncpus"],
  "mem": ["Numeric", "$mem"],
  "icgen2host": ["Boolean", "1"]
 },
 "$imagetype": "$imageID",
 "subnetId": "$subnetId",
 "vpcId": "$vpcID",
 "vmType": "$vmType",
 "securityGroupIds": ["$securityGroupID"],
 "region": "$regionName",
 "resourceGroupId": "$rc_rg",
 "sshkey_id": "$sshkey_ID",
 "zone": "$zone"
},
EOF
      )
    done
  done <<<"$tab"
  json_string="${json_string%,}" # remove last comma
  # Combine the JSON objects into a JSON array
  json_data="{\"templates\": [${json_string}]}"
  # Write the JSON data to the output file
  echo "$json_data" > "$ibmcloudgen2_templates"
  echo "JSON templates are created and updated on ibmcloudgen2_templates.json"

  # 7. Create resource template for ibmcloudhpc templates
  ibmcloudhpc_templates="$LSF_RC_IBMCLOUDHPC_CONF/ibmcloudhpc_templates.json"
  # Incrementally build a json string
  json_string=""
  for j in 1 2 3; do
    for i in 2 4 8 16 32 48 64 96 128 176; do
      ncores=$((i / 2))
      # Calculate the template ID dynamically
      if [ "$j" -eq 1 ]; then
        templateId="Template-${cluster_prefix}-$((j*1000+i))"
        userData="family=mx2"
        family="mx2"
        maxmem=$((ncores * 16 * 1024))
        mem=$((maxmem * 9 / 10))
      elif [ "$j" -eq 2 ]; then
        templateId="Template-${cluster_prefix}-$((j*1000+i))"
        userData="family=cx2"
        family="cx2"
        maxmem=$((ncores * 4 * 1024))
        mem=$((maxmem * 9 / 10))
      else
        templateId="Template-${cluster_prefix}-$((j*1000+i))"
        userData="family=mx3d"
        family="mx3d"
        maxmem=$((ncores * 20 * 1024))
        mem=$((maxmem * 9 / 10))
      fi
      vpcus=$i

      if $hyperthreading; then
        ncpus=$vpcus
       else
        ncpus=$ncores
      fi
      if [ "${imageID:0:4}" == "crn:" ]; then
        imagetype="imageCrn"
      else
        imagetype="imageId"
      fi

      # Construct JSON object (including final comma)
      json_string+=$(cat <<EOF
{
 "templateId": "$templateId",
 "maxNumber": "$rc_max_num",
 "attributes": {
  "type": ["String", "X86_64"],
  "ncores": ["Numeric", "$ncores"],
  "ncpus": ["Numeric", "$ncpus"],
  "mem": ["Numeric", "$mem"],
  "maxmem": ["Numeric", "$maxmem"],
  "cloudhpchost": ["Boolean", "1"],
  "family": ["String", "$family"]
 },
 "$imagetype": "$imageID",
 "vpcId": "${vpcID}",
 "region": "${regionName}",
 "priority": 10,
 "userData": "$userData",
 "ibmcloudhpc_fleetconfig": "ibmcloudhpc_fleetconfig_${family}.json"
},
EOF
      )
    done
  done
  json_string="${json_string%,}" # remove last comma
  # Combine the JSON objects into a JSON array
  json_data="{\"templates\": [${json_string}]}"
  # Write the JSON data to the output file
  echo "$json_data" > "$ibmcloudhpc_templates"
  echo "JSON templates are created and updated on ibmcloudhpc_templates.json"

  # 8. ibmcloudfleet_config.json
  for i in mx2 cx2 mx3d; do
  cat <<EOT > "$LSF_RC_IBMCLOUDHPC_CONF"/ibmcloudhpc_fleetconfig_${i}.json
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
            }
        ],
        "profile_requirement": {
            "families": [
                {
                    "name": "$i",
                    "rank": 1,
                    "profiles": []
                }
            ]
        }
    }
}
EOT
  done
  chown lsfadmin:root "$LSF_RC_IBMCLOUDHPC_CONF"/ibmcloudhpc_fleetconfig*
  chmod 644 "$LSF_RC_IBMCLOUDHPC_CONF"/ibmcloudhpc_fleetconfig*

  # 9. create user_data.json for compute nodes
  (
  cat <<EOT
#!/bin/bash

# Initialize variables
compute_user_data_vars_ok=1
logfile=/tmp/user_data.log
cluster_prefix="${cluster_prefix}"
rc_cidr_block="${rc_cidr_block}"
network_interface="${network_interface}"
dns_domain="${dns_domain}"
ManagementHostNames="${ManagementHostNames}"
lsf_public_key="${cluster_public_key_content}"
hyperthreading=${hyperthreading}
nfs_server_with_mount_path="${nfs_server_with_mount_path}"
custom_file_shares="${custom_file_shares}"
custom_mount_paths="${custom_mount_paths}"
login_ip_address="${login_ip_address}"
login_hostname="${login_hostname}"
enable_ldap="${enable_ldap}"
ldap_server_ip="${ldap_server_ip}"
base_dn="${ldap_basedns}"
enable_cloud_monitoring="${enable_cloud_monitoring}"
enable_compute_node_monitoring="${enable_compute_node_monitoring}"
cloud_monitoring_access_key="${cloud_monitoring_access_key}"
cloud_monitoring_ingestion_url="${cloud_monitoring_ingestion_url}"

# The following line is used to inject extra variables by using a string replacement.
%EXPORT_USER_DATA%

EOT
  cat compute_user_data_fragment.sh
  ) > "$LSF_RC_IBMCLOUDHPC_CONF"/user_data.sh

  # TODO: Setting up License Scheduler configurations
  # No changes has been advised to be automated

  # 10. Copy user_data.sh from ibmcloudhpc to ibmcloudgen2
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

  # Uncomment the below line to enable Datamanager
  cat <<EOT >> $LSF_CONF_FILE
#LSF_DATA_HOSTS=${HostName}
# LSF_DATA_PORT=1729
EOT

  echo "LSF configuration end"
  ##### LSFSETUP-END #####

  # Finally ensure ownership for conf files
  chown -R lsfadmin:root $LSF_RC_IBMCLOUDHPC_CONF

else

  # nothing to do on candidate nodes
  echo "LSF configuration not to be done on secondary nodes, skipping"

fi

########### LSFSETUP-END ##################################################################
###########################################################################################

echo "Setting LSF share"
# Setup file share
if [ -n "${nfs_server_with_mount_path}" ]; then
  echo "File share ${nfs_server_with_mount_path} found"
  # Create a data directory for sharing HPC workload data       ### is this used?
  mkdir -p "${LSF_TOP}/data"
  nfs_client_mount_path="/mnt/lsf"
  rm -rf "${nfs_client_mount_path}"
  mkdir -p "${nfs_client_mount_path}"
  # Mount LSF TOP
  mount -t nfs4 -o sec=sys,vers=4.1 "$nfs_server_with_mount_path" "$nfs_client_mount_path"
  # Verify mount
  if mount | grep "$nfs_client_mount_path"; then
    echo "Mount found"
  else
    echo "No mount found, exiting!"
    exit 1
  fi
  # Update mount to fstab for automount
  echo "$nfs_server_with_mount_path $nfs_client_mount_path nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab

  # Move stuff to shared fs
  for dir in conf work das_staging_area; do
    if [ "$on_primary" == "true" ]; then
      rm -rf "${nfs_client_mount_path}/$dir" # avoid old data already in shared fs
      mv "${LSF_TOP}/$dir" "${nfs_client_mount_path}" # this local data goes to shared fs
    else
      rm -rf "${LSF_TOP}/$dir" # this local data can go away
    fi
    ln -fs "${nfs_client_mount_path}/$dir" "${LSF_TOP}" # locally link to shared fs
    chown -R lsfadmin:root "${LSF_TOP}"
  done

  # Sharing the lsfsuite..conf folder
  if [ "$on_primary" == "true" ]; then
    rm -rf "${nfs_client_mount_path}/gui-conf"
    mv "${LSF_SUITE_GUI_CONF}" "${nfs_client_mount_path}/gui-conf"
    chown -R lsfadmin:root "${nfs_client_mount_path}/gui-conf"
  else
    rm -rf "${LSF_SUITE_GUI_CONF}"
  fi
  ln -fs "${nfs_client_mount_path}/gui-conf" "${LSF_SUITE_GUI_CONF}"
  chown -R lsfadmin:root "${LSF_SUITE_GUI_CONF}"

  # VNC Sessions
  if [ "$on_primary" == "true" ]; then
    mkdir -p "${nfs_client_mount_path}/repository-path"
    # With this change, LDAP User can able to submit the job from App Center UI.
    chmod -R 777 "${nfs_client_mount_path}/repository-path"
    chown -R lsfadmin:root "${nfs_client_mount_path}/repository-path"
  fi

  # Create folder in shared file system to store logs
  mkdir -p "${nfs_client_mount_path}/log/${HOSTNAME}"
  chown -R lsfadmin:root "${nfs_client_mount_path}/log"
  if [ "$(ls -A ${LSF_TOP}/log)" ]; then
    # Move all existing logs to the new folder
    mv ${LSF_TOP}/log/* "${nfs_client_mount_path}/log/${HOSTNAME}"
  fi
  # Remove the original folder and create symlink so the user can still access to default location
  rm -rf "${LSF_TOP}/log"
  ln -fs "${nfs_client_mount_path}/log/${HOSTNAME}" "${LSF_TOP}/log"
  chown -R lsfadmin:root "${LSF_TOP}/log"

  # Create log folder for pac and set proper owner
  mkdir -p "${nfs_client_mount_path}/gui-logs"
  chown -R lsfadmin:root "${nfs_client_mount_path}/gui-logs"
  # Move PAC logs to shared folder
  mkdir -p "${nfs_client_mount_path}/gui-logs/${HOSTNAME}"
  if [ -d "${LSF_SUITE_GUI}/logs/${HOSTNAME}" ] && [ "$(ls -A ${LSF_SUITE_GUI}/logs/"${HOSTNAME}")" ]; then
    mv "${LSF_SUITE_GUI}/logs/${HOSTNAME}" "${nfs_client_mount_path}/gui-logs/${HOSTNAME}"
  fi
  chown -R lsfadmin:root "${nfs_client_mount_path}/gui-logs/${HOSTNAME}"
  ln -fs "${nfs_client_mount_path}/gui-logs/${HOSTNAME}" "${LSF_SUITE_GUI}/logs/${HOSTNAME}"
  chown -R lsfadmin:root "${LSF_SUITE_GUI}/logs/${HOSTNAME}"
else
  echo "No mount point value found, exiting!"
  exit 1
fi
echo "Setting LSF share is completed."

# Setup Custom file shares
echo "Setting custom file shares."
# Setup file share
if [ -n "${custom_file_shares}" ]; then
  echo "Custom file share ${custom_file_shares} found"
  file_share_array=(${custom_file_shares})
  mount_path_array=(${custom_mount_paths})
  length=${#file_share_array[@]}
  for (( i=0; i<length; i++ )); do
    rm -rf "${mount_path_array[$i]}"
    mkdir -p "${mount_path_array[$i]}"
    # Mount LSF TOP
    mount -t nfs4 -o sec=sys,vers=4.1 "${file_share_array[$i]}" "${mount_path_array[$i]}"
    # Verify mount
    if mount | grep "${file_share_array[$i]}"; then
      echo "Mount found"
    else
      echo "No mount found"
      rm -rf "${mount_path_array[$i]}"
    fi
    # Update permission to 777 for all users to access
    chmod 777 "${mount_path_array[$i]}"
    # Update mount to fstab for automount
    echo "${file_share_array[$i]} ${mount_path_array[$i]} nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 " >> /etc/fstab
  done
fi
echo "Setting custom file shares is completed."

# Setup ip-host mapping in LSF_HOSTS_FILE
if [ "$on_primary" == "true" ]; then
  python3 -c "import ipaddress; print('\n'.join([str(ip) + ' ${cluster_prefix}-' + str(ip).replace('.', '-') for ip in ipaddress.IPv4Network('${rc_cidr_block}')]))" >> "$LSF_HOSTS_FILE"
else
  while [ ! -f  "$LSF_HOSTS_FILE" ]; do
    echo "Waiting for cluster configuration created by management node to be shared."
    sleep 5s
  done
fi

# Update the entry to LSF_HOSTS_FILE

if [ "$on_primary" == "true" ]; then
  for hostname in $ManagementHostNames; do
    while true; do
      echo "querying DNS: $hostname"
      ip="$(dig +short "$hostname.${dns_domain}")"
      if [ "$ip" != "" ]; then
        sed -i "s/^$ip .*/$ip $hostname/g" $LSF_HOSTS_FILE
        break
      fi
      sleep 2
    done
    echo "$hostname $ip added to LSF host file"
  done
fi

for hostname in $ManagementHostNames; do
  while ! grep "$hostname" "$LSF_HOSTS_FILE"; do
    echo "Waiting for $hostname to be added to LSF host file"
    sleep 5
  done
  echo "$hostname found in LSF host file"
done
cat $LSF_HOSTS_FILE >> /etc/hosts

if [ "$enable_app_center" = true ] && [ "${app_center_high_availability}" = true ]; then
  # Add entry for VNC scenario
  echo "127.0.0.1 pac pac.$dns_domain" >> /etc/hosts
fi

# Create lsf.sudoers file to support single lsfstartup and lsfrestart command from management node
cat <<EOT > "/etc/lsf.sudoers"
LSF_STARTUP_USERS="lsfadmin"
LSF_STARTUP_PATH=$LSF_TOP_VERSION/linux3.10-glibc2.17-x86_64/etc/
EOT
chmod 600 /etc/lsf.sudoers
ls -l /etc/lsf.sudoers

$LSF_TOP_VERSION/install/hostsetup --top="$LSF_TOP" --setuid
echo "Added LSF administrators to start LSF daemons"

lsfadmin_home_dir="/home/lsfadmin"
echo "source ${LSF_CONF}/profile.lsf" >> /root/.bashrc
echo "source ${LSF_CONF}/profile.lsf" >> "${lsfadmin_home_dir}"/.bashrc

if [ "$on_primary" == "true" ]; then
  # Configure and start perfmon, used for lsf prometheus monitoring
  sed -i '/^End Parameters/i SCHED_METRIC_ENABLE=Y' $LSF_CONF/lsbatch/"$cluster_name"/configdir/lsb.params
fi

do_app_center=false
if [ "$enable_app_center" = true ] ; then
  if [ "$on_primary" == "true" ] || [ "${app_center_high_availability}" = true ] ; then
    do_app_center=true
  fi
fi
# Setting up the Application Center
if [ "$do_app_center" = true ] ; then
  if rpm -q lsf-appcenter; then
    echo "Application center packages are found..."
    echo "${app_center_gui_pwd}" | passwd --stdin lsfadmin
    sed -i '$i\\ALLOW_EVENT_TYPE=JOB_NEW JOB_STATUS JOB_FINISH2 JOB_START JOB_EXECUTE JOB_EXT_MSG JOB_SIGNAL JOB_REQUEUE JOB_MODIFY2 JOB_SWITCH METRIC_LOG' $LSF_CONF/lsbatch/"$cluster_name"/configdir/lsb.params
    sed -i 's/NEWJOB_REFRESH=y/NEWJOB_REFRESH=Y/g' $LSF_CONF/lsbatch/"$cluster_name"/configdir/lsb.params

    if [ "${app_center_high_availability}" = true ]; then
      create_certificate
      configure_icd_datasource
    fi

    if [ "$on_primary" == "true" ]; then
      # Update the Job directory, needed for VNC Sessions
      sed -i 's|<Path>/home</Path>|<Path>/mnt/lsf/repository-path</Path>|' "$LSF_SUITE_GUI_CONF/Repository.xml"
      if [ "${app_center_high_availability}" = true ]; then
        echo "LSF_ADDON_HOSTS=\"${ManagementHostNames}\"" >> $LSF_CONF/lsf.conf
        create_appcenter_database
        sed -i "s/NoVNCProxyHost=.*/NoVNCProxyHost=pac.${dns_domain}/g" "$LSF_SUITE_GUI_CONF/pmc.conf"
        sed -i "s|<restHost>.*</restHost>|<restHost>pac.${dns_domain}</restHost>|" $LSF_SUITE_GUI_CONF/pnc-config.xml
        sed -i "s|<wsHost>.*</wsHost>|<wsHost>pac.${dns_domain}</wsHost>|" $LSF_SUITE_GUI_CONF/pnc-config.xml
      else
        echo "LSF_ADDON_HOSTS=$HOSTNAME" >> $LSF_CONF/lsf.conf
        sed -i 's/NoVNCProxyHost=.*/NoVNCProxyHost=localhost/g' "$LSF_SUITE_GUI_CONF/pmc.conf"
      fi
    fi

    echo "source $LSF_SUITE_TOP/ext/profile.platform" >> ~/.bashrc
    echo "source $LSF_SUITE_TOP/ext/profile.platform" >> "${lsfadmin_home_dir}"/.bashrc
    rm -rf $LSF_SUITE_GUI/3.0/bin/novnc.pem
  fi
else
  echo 'Application Center installation skipped...'
fi

# Startup lsf daemons

echo 'Ready to start daemons'

# only start after the primary node gives a green-light
if [ "$on_primary" == "true" ]; then
  touch /mnt/lsf/config_done
fi
while true; do
  [ -f /mnt/lsf/config_done ] && break
  echo "waiting, not starting yet"
  sleep 3
  ls -l /mnt/lsf /mnt/lsf/config_done 1>/dev/null 2>&1 # creating some NFS activity
done
echo "got green light for starting"

### useless and this dangerously unsets LSF_TOP and LSF_VERSION
#if [ "$on_primary" == "true" ]; then
#  . $LSF_TOP/conf/profile.lsf
#fi

$LSF_TOP_VERSION/install/hostsetup --top="$LSF_TOP" --boot="y" --start="y"
systemctl status lsfd

### warning: this dangerously unsets LSF_TOP and LSF_VERSION
source ~/.bashrc

if [ "$do_app_center" = true ] ; then
  # Start all the PerfMonitor and WEBUI processes.
  nohup >/tmp/perfout setsid perfadmin start all; perfadmin list
  sleep 5
  nohup >/tmp/pmcout setsid pmcadmin start; pmcadmin list
  appcenter_status=$(pmcadmin list | grep "WEBGUI" | awk '{print $2}')
  if [ "$appcenter_status" = "STARTED" ]; then
      echo "Application Center installation completed..."
  else
      echo "Application Center installation failed..."
  fi
fi


# Setup start at boot
# Lsf processes are started by systemctl.
# The script '/root/lsf_start_pac' manages the start of PAC processes if in HA.
if [ "$do_app_center" = "true" ]; then
  echo "Configuring the start of the Pac"
  cat <<EOT > /root/lsf_start_pac
#!/bin/sh

logfile=/tmp/lsf_start_pac.log
echo "\$(date +'%Y%m%d_%H%M%S'): START" > \$logfile

# Wait mount point just to be sure it is ready
while [ ! mountpoint /mnt/lsf ]; do
        sleep 1;
done
echo "\$(date +'%Y%m%d_%H%M%S'): File system '/mnt/lsf' is mounted" >> \$logfile

# Waiting lsf processes before starting PAC
source ~/.bashrc
RC=1
x=1
while [ \$RC -eq 1 ] && [ \$x -le 600 ]; do
        lsf_daemons status >> \$logfile; RC=\$?
        echo "\$(date +'%Y%m%d_%H%M%S'): RC=\$RC; attempt #\$x" >> \$logfile
        x=\$((x+1))
        sleep \$((\$x / 10 + 1))
done
echo "END" >> \$logfile
perfadmin start all >> \$logfile
sleep 5
pmcadmin start >> \$logfile
echo "EXIT" >> \$logfile

EOT
  chmod 755 /root/lsf_start_pac
  command="/root/lsf_start_pac"
  (crontab -l 2>/dev/null; echo "@reboot  $command") | crontab -
fi


# Setting up the LDAP configuration
if [ "$enable_ldap" = "true" ]; then

    # Detect RHEL version
    rhel_version=$(grep -oE 'release [0-9]+' /etc/redhat-release | awk '{print $2}')

    if [ "$rhel_version" = "8" ]; then
        echo "Detected RHEL 8. Proceeding with LDAP client configuration...."

        # Allow Password authentication
        sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
        systemctl restart sshd

        # Configure LDAP authentication
        authconfig --enableldap --enableldapauth \
                    --ldapserver=ldap://"${ldap_server_ip}" \
                    --ldapbasedn="dc=${base_dn%%.*},dc=${base_dn#*.}" \
                    --enablemkhomedir --update

        # Check the exit status of the authconfig command
        if [ $? -eq 0 ]; then
            echo "LDAP Authentication enabled successfully."
        else
            echo "Failed to enable LDAP and LDAP Authentication."
            exit 1
        fi

        # Update LDAP Client configurations in nsswitch.conf
        sed -i -e 's/^passwd:.*$/passwd: files ldap/' -e 's/^shadow:.*$/shadow: files ldap/' -e 's/^group:.*$/group: files ldap/' /etc/nsswitch.conf  # pragma: allowlist secret

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
        if ldapsearch -x -H ldap://"${ldap_server_ip}"/ -b "dc=${base_dn%%.*},dc=${base_dn#*.}" > /dev/null; then
            echo "LDAP configuration completed successfully !!"
        else
            echo "LDAP configuration failed !!"
            exit 1
        fi

        # Make LSF commands available for every user.
        echo ". ${LSF_CONF}/profile.lsf" >> /etc/bashrc
        source /etc/bashrc
    else
        echo "This script is designed for RHEL 8. Detected RHEL version: $rhel_version. Exiting."
        exit 1
    fi
fi

# Manually start perfmon, used by monitoring
# This is not needed, given that SCHED_METRIC_ENABLE=Y
#su - lsfadmin -c "badmin perfmon start"

# Ensure lsf_prometheus_exporter service to be executed after shared filesystem mount
sed -i 's/After=network-online.target/After=network-online.target mnt-lsf.mount/g' /etc/systemd/system/lsf_prometheus_exporter.service
systemctl daemon-reload

# Enable LSF prometheus exporter
systemctl enable lsf_prometheus_exporter
systemctl restart lsf_prometheus_exporter

# Setting up the Metrics Agent
if [ "$enable_cloud_monitoring" = true ]; then

  if [ "$cloud_monitoring_access_key" != "" ] && [ "$cloud_monitoring_ingestion_url" != "" ]; then

    SYSDIG_CONFIG_FILE="/opt/draios/etc/dragent.yaml"
    PROMETHEUS_CONFIG_FILE="/opt/prometheus/prometheus.yml"

    #packages installation
    echo "Writing sysdig config file"

    #sysdig config file
    echo "Setting customerid access key"
    sed -i "s/==ACCESSKEY==/$cloud_monitoring_access_key/g" $SYSDIG_CONFIG_FILE
    sed -i "s/==COLLECTOR==/$cloud_monitoring_ingestion_url/g" $SYSDIG_CONFIG_FILE
    echo "tags: type:management,lsf:true" >> $SYSDIG_CONFIG_FILE

    cat <<EOTF > $PROMETHEUS_CONFIG_FILE
global:
  scrape_interval: 60s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

scrape_configs:
  - job_name: "lsf_prometheus_exporter"
    static_configs:
      - targets: ["localhost:9405"]
remote_write:
- url: "$cloud_monitoring_prws_url"
  authorization:
    credentials: "$cloud_monitoring_prws_key"
EOTF

    # Enable prometheus
    systemctl enable prometheus
    systemctl restart prometheus

    echo "Restarting sysdig agent"
    systemctl enable dragent
    systemctl restart dragent
  else
    echo "Skipping metrics agent configuration due to missing parameters"
  fi
else
  echo "Metrics agent configuration skipped since monitoring provisioning is not enabled"
fi

echo "END $(date '+%Y-%m-%d %H:%M:%S')"
sleep 0.1 # don't race against the log
