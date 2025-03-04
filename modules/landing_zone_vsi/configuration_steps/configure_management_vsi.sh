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
nfs_server_with_mount_path=${mount_path}
enable_ldap="${enable_ldap}"
ldap_server_ip="${ldap_server_ip}"
ldap_server_cert="${ldap_server_cert}"
base_dn="${ldap_basedns}"

this_hostname="$(hostname)"
mgmt_hostname_primary="$management_hostname"
mgmt_hostnames="${management_hostname},${management_cand_hostnames}"
mgmt_hostnames="${mgmt_hostnames//,/ }" # replace commas with spaces
mgmt_hostnames="${mgmt_hostnames# }" # remove an initial space
mgmt_hostnames="${mgmt_hostnames% }" # remove a final space

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
LSF_SUITE_GUI_WORK="${LSF_SUITE_GUI}/work"
LSF_SUITE_PERF="${LSF_SUITE_TOP}/ext/perf"
LSF_SUITE_PERF_CONF="${LSF_SUITE_PERF}/conf"
LSF_SUITE_PERF_BIN="${LSF_SUITE_PERF}/1.2/bin"

# important: is this a primary or secondary management node?
if [ "$this_hostname" == "$mgmt_hostname_primary" ]; then
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

if [ "$solution" = "lsf" ]; then
  LSB_RC_EXTERNAL_HOST_FLAG="icgen2host"
elif [ "$solution" = "hpc" ]; then
  LSB_RC_EXTERNAL_HOST_FLAG="icgen2host cloudhpchost"
fi

  # 1. setting up lsf configuration
  cat <<EOT >> $LSF_CONF_FILE
LSB_RC_EXTERNAL_HOST_IDLE_TIME=10
LSF_DYNAMIC_HOST_TIMEOUT="EXPIRY[10m] THRESHOLD[250] INTERVAL[60m]"
LSB_RC_EXTERNAL_HOST_FLAG="$LSB_RC_EXTERNAL_HOST_FLAG"
LSB_RC_UPDATE_INTERVAL=15
LSB_RC_MAX_NEWDEMAND=50
LSF_UDP_TO_TCP_THRESHOLD=9000
LSF_CALL_LIM_WITH_TCP=N
LSF_ANNOUNCE_MASTER_TCP_WAITTIME=600
LSF_CLOUD_UI=Y
LSF_RSH="ssh -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no'"
EOT
  sed -i "s/LSF_MASTER_LIST=.*/LSF_MASTER_LIST=\"${mgmt_hostnames}\"/g" $LSF_CONF_FILE

  if [ "$hyperthreading" == true ]; then
    ego_define_ncpus="threads"
  else
    ego_define_ncpus="cores"

    cat << 'EOT' > /root/lsf_hyperthreading
#!/bin/sh
for vcpu in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d- -f2 | cut -d- -f2 | uniq); do
    echo "0" > "/sys/devices/system/cpu/cpu"$vcpu"/online"
done
EOT
    chmod 755 /root/lsf_hyperthreading
    command="/root/lsf_hyperthreading"
    sh $command && (crontab -l 2>/dev/null; echo "@reboot $command") | crontab -
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
  for hostname in $mgmt_hostnames; do
    sed -i "/^default    !.*/a $hostname  0 () () () () () (Y)" "$LSF_LSBATCH_CONF/lsb.hosts"
  done

  # 6. setting up lsf.cluster."$cluster_name"
  sed -i "s/^lsfservers/#lsfservers/g" "$LSF_CONF/lsf.cluster.$cluster_name"
  sed -i 's/LSF_HOST_ADDR_RANGE=\*.\*.\*.\*/LSF_HOST_ADDR_RANGE=10.*.*.*/' "$LSF_CONF/lsf.cluster.$cluster_name"
  for hostname in $mgmt_hostnames; do
    sed -i "/^#lsfservers.*/a $hostname ! ! 1 (mg)" "$LSF_CONF/lsf.cluster.$cluster_name"
  done

  # Updating the value of login node as Intel for lsfserver to update cluster file name
  sed -i "/^#lsfservers.*/a $login_hostname Intel_E5 X86_64 0 ()" "$LSF_CONF/lsf.cluster.$cluster_name"
  echo "LSF_SERVER_HOSTS=\"$mgmt_hostnames\"" >> $LSF_CONF_FILE

  # Update ego.conf
  sed -i "s/EGO_MASTER_LIST=.*/EGO_MASTER_LIST=\"${mgmt_hostnames}\"/g" "$LSF_EGO_CONF_FILE"
  # 0.5 Update lsfservers with newly added lsf management nodes
  grep -rli 'lsfservers' $LSF_CONF/*|xargs sed -i "s/lsfservers/${this_hostname}/g"

  # Setup LSF resource connector
  echo "Setting up LSF resource connector"

  # 1. Create hostProviders.json
  if [ "$solution" = "hpc" ] ; then
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
    "br-sao": "https://br-sao.iaas.cloud.ibm.com/v1",
    "us-south": "https://us-south.iaas.cloud.ibm.com/v1",
    "eu-de": "https://eu-de.iaas.cloud.ibm.com/v1",
    "us-east": "https://us-east.iaas.cloud.ibm.com/v1"
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
    "PROJECT_ID": "${ce_project_guid}",
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

cat <<EOT > "$LSF_RC_IC_CONF"/ibmcloudgen2_templates.json
{
    "templates": [
        {
            "templateId": "Template-1",
            "maxNumber": "$rc_max_num",
            "attributes": {
                "type": ["String", "X86_64"],
                "ncores": ["Numeric", "${rc_ncores}"],
                "ncpus": ["Numeric", "${rc_ncpus}"],
                "mem": ["Numeric", "${rc_memInMB}"],
                "icgen2host": ["Boolean", "1"]
            },
            "crn": "${bootdrive_crn}",
            "imageId": "$imageID",
            "subnetId": "$subnetId",
            "vpcId": "$vpcID",
            "vmType": "${rc_profile}",
            "securityGroupIds": ["${securityGroupID}"],
            "resourceGroupId": "$rc_rg",
            "sshkey_id": "$sshkey_ID",
            "region": "$regionName",
            "zone": "$zone"
        }
    ]
}
EOT


#cat <<EOT > "$LSF_RC_IC_CONF"/ibmcloudgen2_templates.json
#{
#  templates = [
#    for worker in var.worker_node_instance_type : {
#      templateId    = "Template-${var.cluster_prefix}-${worker.instance_type}"
#      maxNumber     = var.rc_max_num
#      attributes    = {
#        type       = ["String", "X86_64"],
#        ncores     = ["Numeric", worker.count / 2],
#        ncpus      = ["Numeric", var.hyperthreading ? worker.count : worker.count / 2],
#        mem        = ["Numeric", floor((var.hyperthreading ? worker.count : worker.count / 2) * 16 * 1024 * 0.9)],
#        icgen2host = ["Boolean", true]
#      },
#      "crn": "${bootdrive_crn}",
#      "imageId": "$imageID",
#      "subnetId": "$subnetId",
#      "vpcId": "$vpcID"
#      "vmType": "${rc_profile}"
#      "securityGroupIds": ["${securityGroupID}"],
#      "resourceGroupId": "$rc_rg",
#      "sshkey_id": "$sshkey_ID",
#      "region": "$regionName",
#      "zone": "$zone",
#      "vmType": worker.instance_type
#    }
#  ]
#}
#
#EOT
#  # 6. Create ibmcloudgen2_templates.json
#  ibmcloudgen2_templates="$LSF_RC_IC_CONF/ibmcloudgen2_templates.json"
#  # Incrementally build a json string
#  json_string=""
#
#  tab="$(cat <<EOF
#2   mx2-2x16
#4   mx2-4x32
#8   mx2-8x64
#16  mx2-16x128
#32  mx2-32x256
#48  mx2-48x384
#64  mx2-64x512
#96  mx2-96x768
#128 mx2-128x1024
#EOF
#)"
#
#  # Loop over table entries
#  while read i vmType; do
#    # Construct JSON object
#    for j in 1; do
#      # Set template ID based on j
#      if [ "$j" -eq 1 ]; then
#        templateId="Template-$cluster_prefix-$((j*1000+i))"
#        subnetId="${subnetID}"
#        zone="${zoneName}"
#      fi
#
#      # Construct JSON object
#      vpcus=$i
#      ncores=$((i / 2))
#      if $hyperthreading; then
#          ncpus=$vpcus
#      else
#          ncpus=$ncores
#      fi
#      maxmem=$((ncores * 16 * 1024))
#      mem=$((maxmem * 9 / 10))
#      if [ "${imageID:0:4}" == "crn:" ]; then
#        imagetype="imageCrn"
#      else
#        imagetype="imageId"
#      fi
#      json_string+=$(cat <<EOF
#{
# "templateId": "$templateId",
# "maxNumber": "$rc_max_num",
# "attributes": {
#  "type": ["String", "X86_64"],
#  "ncores": ["Numeric", "$ncores"],
#  "ncpus": ["Numeric", "$ncpus"],
#  "mem": ["Numeric", "$mem"],
#  "icgen2host": ["Boolean", "1"]
# },
# "$imagetype": "$imageID",
# "subnetId": "$subnetId",
# "vpcId": "$vpcID",
# "vmType": "$vmType",
# "securityGroupIds": ["$securityGroupID"],
# "region": "$regionName",
# "resourceGroupId": "$rc_rg",
# "sshkey_id": "$sshkey_ID",
# "zone": "$zone"
#},
#EOF
#      )
#    done
#  done <<<"$tab"
#  json_string="${json_string%,}" # remove last comma
#  # Combine the JSON objects into a JSON array
#  json_data="{\"templates\": [${json_string}]}"
#  # Write the JSON data to the output file
#  echo "$json_data" > "$ibmcloudgen2_templates"
#  echo "JSON templates are created and updated on ibmcloudgen2_templates.json"

# 7. Create resource template for ibmcloudhpc templates
# Define the output JSON file path

ibmcloudhpc_templates="$LSF_RC_IBMCLOUDHPC_CONF/ibmcloudhpc_templates.json"

# Initialize an empty JSON string
json_string=""

# Loop through the specified regions
for region in "eu-de" "us-east" "us-south"; do
  if [ "$region" = "$regionName" ]; then
    # Loop through the core counts
    for i in 2 4 8 16 32 48 64 96 128 176; do
      if [ "$i" -gt 128 ] && [ "$region" != "us-south" ]; then
        # Skip creating templates with more than 128 cores for non us-south regions
        continue
      fi

      ncores=$((i / 2))
      if [ "$region" = "eu-de" ] || [ "$region" = "us-east" ]; then
        family="mx2"
        maxmem_mx2=$((ncores * 16 * 1024))
        mem_mx2=$((maxmem_mx2 * 9 / 10))
      elif [ "$region" = "us-south" ]; then
        family="mx2,mx3d"  # Include both "mx2" and "mx3d" families
        maxmem_mx2=$((ncores * 16 * 1024))
        mem_mx2=$((maxmem_mx2 * 9 / 10))
        maxmem_mx3d=$((ncores * 20 * 1024))
        mem_mx3d=$((maxmem_mx3d * 9 / 10))
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

      # Split the family string into an array and iterate over it
      IFS=',' read -ra families <<< "$family"
      for fam in "${families[@]}"; do
        # Check if the core count is valid for the family
        if [ "$fam" = "mx2" ] && [ "$i" -gt 128 ]; then
          continue
        fi

        templateId="Template-${cluster_prefix}-$((1000+i))-$fam"  # Add family to templateId
        if [ "$fam" = "mx2" ]; then
          maxmem_val="$maxmem_mx2"  # Use mx2 specific maxmem value
          mem_val="$mem_mx2"  # Use mx2 specific mem value
          priority=10  # Priority for mx2
        elif [ "$fam" = "mx3d" ]; then
          maxmem_val="$maxmem_mx3d"  # Use mx3d specific maxmem value
          mem_val="$mem_mx3d"  # Use mx3d specific mem value
          priority=20  # Priority for mx3d in us-south
        fi

        # Construct JSON object and append it to the JSON string
        json_string+=$(cat <<EOF
{
 "templateId": "$templateId",
 "maxNumber": $rc_max_num,
 "attributes": {
  "type": ["String", "X86_64"],
  "ncores": ["Numeric", "$ncores"],
  "ncpus": ["Numeric", "$ncpus"],
  "mem": ["Numeric", "$mem_val"],
  "maxmem": ["Numeric", "$maxmem_val"],
  "cloudhpchost": ["Boolean", "1"],
  "family": ["String", "$fam"]
 },
 "$imagetype": "$imageID",
 "vpcId": "${vpcID}",
 "region": "${regionName}",
 "priority": $priority,
 "userData": "family=$fam",
 "ibmcloudhpc_fleetconfig": "ibmcloudhpc_fleetconfig_${fam}.json"
},
EOF
)
      done
    done
  fi
done

# Remove the trailing comma from the JSON string
json_string="${json_string%,}"
# Combine the JSON objects into a JSON array
json_data="{\"templates\": [${json_string}]}"
# Write the JSON data to the output file
echo "$json_data" > "$ibmcloudhpc_templates"
echo "JSON templates are created and updated in ibmcloudhpc_templates.json"

# 8. Define the directory to store fleet configuration files
fleet_config_dir="$LSF_RC_IBMCLOUDHPC_CONF"
# Loop through regions
for region in "eu-de" "us-east" "us-south"; do
    # Define the fleet configuration family based on the region
    if [ "$regionName" = "us-south" ]; then
        families=("mx2" "mx3d")
    else
        families=("mx2")
    fi

    # Loop through families
    for family in "${families[@]}"; do
        # Create fleet configuration file for the region and family
        cat <<EOT > "${fleet_config_dir}/ibmcloudhpc_fleetconfig_${family}.json"
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
                    "name": "${family}",
                    "rank": 1,
                    "profiles": []
                }
            ]
        }
    }
}
EOT
    done
done

# Set permissions for fleet configuration files
chown lsfadmin:root "${fleet_config_dir}/ibmcloudhpc_fleetconfig_"*
chmod 644 "${fleet_config_dir}/ibmcloudhpc_fleetconfig_"*
echo "Fleet configuration files created and updated."

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
ManagementHostNames="${mgmt_hostnames}"
lsf_public_key="${cluster_public_key_content}"
hyperthreading=${hyperthreading}
nfs_server_with_mount_path="${nfs_server_with_mount_path}"
custom_file_shares="${custom_file_shares}"
custom_mount_paths="${custom_mount_paths}"
login_ip_address="${login_ip}"
login_hostname="${login_hostname}"
enable_ldap="${enable_ldap}"
ldap_server_ip="${ldap_server_ip}"
base_dn="${ldap_basedns}"
observability_monitoring_enable="${observability_monitoring_enable}"
observability_monitoring_on_compute_nodes_enable="${observability_monitoring_on_compute_nodes_enable}"
cloud_monitoring_access_key="${cloud_monitoring_access_key}"
cloud_monitoring_ingestion_url="${cloud_monitoring_ingestion_url}"
observability_logs_enable_for_compute="${observability_logs_enable_for_compute}"
cloud_logs_ingress_private_endpoint="${cloud_logs_ingress_private_endpoint}"
VPC_APIKEY_VALUE="${VPC_APIKEY_VALUE}"

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
#LSF_DATA_HOSTS=${this_hostname}
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

echo "Initiating LSF share mount"

# Function to attempt NFS mount with retries
mount_nfs_with_retries() {
  local server_path=$1
  local client_path=$2
  local retries=5
  local success=false

  rm -rf "${client_path}"
  mkdir -p "${client_path}"

  for (( j=0; j<retries; j++ )); do
    mount -t nfs -o sec=sys "$server_path" "$client_path" -v >> $logfile
    if mount | grep -q "${client_path}"; then
      echo "Mount successful for ${server_path} on ${client_path}"
      success=true
      break
    else
      echo "Attempt $((j+1)) of $retries failed for ${server_path} on ${client_path}"
      sleep 2
    fi
  done

  if [ "$success" = true ]; then
    chmod 777 "${client_path}"
    echo "${server_path} ${client_path} nfs rw,sec=sys,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab
  else
    echo "Mount not found for ${server_path} on ${client_path} after $retries attempts."
    rm -rf "${client_path}"
  fi

  # Convert success to numeric for return
  if [ "$success" = true ]; then
    return 0
  else
    return 1
  fi
}

# Setup LSF share
if [ -n "${nfs_server_with_mount_path}" ]; then
  echo "File share ${nfs_server_with_mount_path} found"
  nfs_client_mount_path="/mnt/lsf"
  nfs_client_mount_pac_path="${nfs_client_mount_path}/pac"
  if mount_nfs_with_retries "${nfs_server_with_mount_path}" "${nfs_client_mount_path}"; then
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

    # Check if LDAP is enabled and the existing LDAP server certificate is provided
    if [ "$on_primary" == "true" ] && [ "$enable_ldap" == "true" ] && [ "$ldap_server_cert" != "null" ]; then
        mkdir -p /mnt/lsf/openldap
        echo "$ldap_server_cert" > /mnt/lsf/openldap/ldap_cacert.pem
        chmod 755 /mnt/lsf/openldap/ldap_cacert.pem
        cp -pr /mnt/lsf/openldap/ldap_cacert.pem /etc/openldap/certs/ldap_cacert.pem
       echo "Configuring with the existing LDAP server. Existing LDAP server certificate found. Proceeding with the setup!"
    fi

    # Sharing the lsfsuite.conf folder
    if [ "$on_primary" == "true" ] && [ "$enable_app_center" == "true" ] && [ "$app_center_high_availability" == "true" ]; then
        # Create pac folder if it does not exist
        [ ! -d "${nfs_client_mount_pac_path}" ] && mkdir -p "${nfs_client_mount_pac_path}"

        # Remove the original folder and create symlink for gui-conf
        [ -d "${nfs_client_mount_pac_path}/gui-conf" ] && rm -rf "${nfs_client_mount_pac_path}/gui-conf"
        mv "${LSF_SUITE_GUI_CONF}" "${nfs_client_mount_pac_path}/gui-conf"
        chown -R lsfadmin:root "${nfs_client_mount_pac_path}/gui-conf" && chown -R lsfadmin:lsfadmin "${LSF_SUITE_GUI_CONF}"
        ln -fs "${nfs_client_mount_pac_path}/gui-conf" "${LSF_SUITE_GUI_CONF}"

        # Remove the original folder and create symlink for gui-work
        [ -d "${nfs_client_mount_pac_path}/gui-work" ] && rm -rf "${nfs_client_mount_pac_path}/gui-work"
        mv "${LSF_SUITE_GUI_WORK}" "${nfs_client_mount_pac_path}/gui-work"
        chown -R lsfadmin:root "${nfs_client_mount_pac_path}/gui-work" && chown -R lsfadmin:lsfadmin "${LSF_SUITE_GUI_WORK}"
        ln -fs "${nfs_client_mount_pac_path}/gui-work" "${LSF_SUITE_GUI_WORK}"
    fi

    # Create a data directory for sharing HPC workload data
    if [ "$on_primary" == "true" ]; then
      mkdir -p "${nfs_client_mount_path}/data"
      ln -s "${nfs_client_mount_path}/data" "$LSF_TOP/work/data"
      chown -R lsfadmin:root "$LSF_TOP/work/data"
    fi

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
    if [ -d "${LSF_SUITE_GUI}/logs/${HOSTNAME}" ] && [ "$(ls -A ${LSF_SUITE_GUI}/logs/${HOSTNAME})" ]; then
      mv "${LSF_SUITE_GUI}/logs/${HOSTNAME}" "${nfs_client_mount_path}/gui-logs/${HOSTNAME}"
    fi
    chown -R lsfadmin:root "${nfs_client_mount_path}/gui-logs/${HOSTNAME}"
    ln -fs "${nfs_client_mount_path}/gui-logs/${HOSTNAME}" "${LSF_SUITE_GUI}/logs/${HOSTNAME}"
    chown -R lsfadmin:root "${LSF_SUITE_GUI}/logs/${HOSTNAME}"
  fi
else
  echo "Mount not found for ${nfs_server_with_mount_path}, Exiting !!"
  exit 1
fi
echo "Setting LSF share is completed."

# Setup Custom file shares
echo "Setting custom file shares."
if [ -n "${custom_file_shares}" ]; then
  echo "Custom file share ${custom_file_shares} found"
  file_share_array=(${custom_file_shares})
  mount_path_array=(${custom_mount_paths})
  length=${#file_share_array[@]}

  for (( i=0; i<length; i++ )); do
    mount_nfs_with_retries "${file_share_array[$i]}" "${mount_path_array[$i]}"
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
  echo "$login_ip $login_hostname" >> $LSF_HOSTS_FILE
  for hostname in $mgmt_hostnames; do
    # we map hostnames to ips with DNS, even if we have the ips list already
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

for hostname in $mgmt_hostnames; do
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

$LSF_TOP_VERSION/install/hostsetup --top="$LSF_TOP" --boot="y" --start="y"
systemctl status lsfd

### warning: this dangerously unsets LSF_TOP and LSF_VERSION
source ~/.bashrc

# Set `do_app_center` based on conditions
do_app_center=false
if [ "$enable_app_center" = true ]; then
  if [ "$on_primary" == "true" ] || [ "${app_center_high_availability}" = true ]; then
    do_app_center=true
  fi
fi

# Main Application Center configuration block for HPC solution
if [ "$do_app_center" = true ] && [ "$solution" = "hpc" ]; then
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
        echo "LSF_ADDON_HOSTS=\"${mgmt_hostnames}\"" >> $LSF_CONF/lsf.conf
        create_appcenter_database
        sed -i "s/NoVNCProxyHost=.*/NoVNCProxyHost=pac.${dns_domain}/g" "$LSF_SUITE_GUI_CONF/pmc.conf"
        sed -i "s|<restHost>.*</restHost>|<restHost>${mgmt_hostname_primary}</restHost>|" $LSF_SUITE_GUI_CONF/pnc-config.xml
        sed -i "s|<wsHost>.*</wsHost>|<wsHost>pac.${dns_domain}</wsHost>|" $LSF_SUITE_GUI_CONF/pnc-config.xml
      else
        echo "LSF_ADDON_HOSTS=$HOSTNAME" >> $LSF_CONF/lsf.conf
        sed -i 's/NoVNCProxyHost=.*/NoVNCProxyHost=localhost/g' "$LSF_SUITE_GUI_CONF/pmc.conf"
        sed -i "s|<restHost>.*</restHost>|<restHost>${mgmt_hostname_primary}</restHost>|" $LSF_SUITE_GUI_CONF/pnc-config.xml
        sed -i "s|<wsHost>.*</wsHost>|<wsHost>localhost</wsHost>|" $LSF_SUITE_GUI_CONF/pnc-config.xml
      fi
    fi

    echo "source $LSF_SUITE_TOP/ext/profile.platform" >> ~/.bashrc
    echo "source $LSF_SUITE_TOP/ext/profile.platform" >> "${lsfadmin_home_dir}"/.bashrc
    rm -rf $LSF_SUITE_GUI/3.0/bin/novnc.pem
  fi
elif [ "$do_app_center" = true ] && [ "$solution" = "lsf" ]; then
  # Alternative configuration block for LSF BYOL scenario
  echo "Configuring the App Center for LSF BYOL"
  if (( $(ls -ltr /opt/IBM/lsf_app_center_cloud_packages/ | grep "pac" | wc -l) > 0 )); then
    echo "Application Center package found!"
    LSF_ENVDIR="/opt/ibm/lsf/conf"
    echo $LSF_ENVDIR
    echo ${app_center_gui_pwd} | sudo passwd --stdin lsfadmin
    sed -i '$i\\ALLOW_EVENT_TYPE=JOB_NEW JOB_STATUS JOB_FINISH2 JOB_START JOB_EXECUTE JOB_EXT_MSG JOB_SIGNAL JOB_REQUEUE JOB_MODIFY2 JOB_SWITCH METRIC_LOG' $LSF_CONF/lsbatch/"$cluster_name"/configdir/lsb.params
    sed -i 's/NEWJOB_REFRESH=y/NEWJOB_REFRESH=Y/g' $LSF_CONF/lsbatch/"$cluster_name"/configdir/lsb.params
    sed -i 's/LSF_DISABLE_LSRUN=Y/LSF_DISABLE_LSRUN=N/g' $LSF_CONF/lsf.conf
    echo "LSF_ADDON_HOSTS=\"${mgmt_hostnames}\"" >> $LSF_CONF/lsf.conf

    # Additional configurations for BYOL
    sudo systemctl status mariadb -l

    if [ "${app_center_high_availability}" = true ]; then
      if [ "$on_primary" == "true" ]; then
        sudo mkdir -p /mnt/lsf/lsf_packages
        chmod 755 /mnt/lsf/lsf_packages
        cp /opt/IBM/lsf_app_center_cloud_packages/pac10.2.0.14_standard_linux-x64.tar.Z /mnt/lsf/lsf_packages
      fi
        # If we're on a secondary node, copy the package from /mnt/lsf/lsf_packages
      if [ "$on_primary" != "true" ]; then
        cp /mnt/lsf/lsf_packages/pac10.2.0.14_standard_linux-x64.tar.Z /opt/IBM/lsf_app_center_cloud_packages
      fi
    fi

    cd /opt/IBM/lsf_app_center_cloud_packages
    tar -xvf pac10.2.0.14_standard_linux-x64.tar.Z
    cd pac10.2.0.14_standard_linux-x64
    sed -i '1i export SHARED_CONFIGURATION_DIR="/mnt/lsf/pac"' pacinstall.sh
    sed -i 's/#\ \.\ $LSF_ENVDIR\/profile\.lsf/. \/opt\/ibm\/lsf\/conf\/profile\.lsf/g' pacinstall.sh
    sed -i 's/# export PAC_ADMINS=\"user1 user2\"/export PAC_ADMINS=\"lsfadmin\"/g' pacinstall.sh

    mkdir -p $LSF_CONF/work/"$cluster_name"/logdir/stream
    touch $LSF_CONF/work/"$cluster_name"/logdir/stream/lsb.stream

    ./pacinstall.sh -s -y >> $logfile
    echo "Sleeping for 10 seconds..."
    sleep 10

    until rpm -qa | grep lsf-appcenter; do
      sleep 10  # Check every 10 seconds
    done
    echo "lsf-appcenter RPM is available, proceeding with configurations..."

    if [ "${app_center_high_availability}" = true ]; then
      create_certificate
      configure_icd_datasource
    fi

    if [ "$on_primary" == "true" ]; then
      # Update the Job directory, needed for VNC Sessions
      sed -i 's|<Path>/home</Path>|<Path>/mnt/lsf/repository-path</Path>|' "$LSF_SUITE_GUI_CONF/Repository.xml"
      if [ "${app_center_high_availability}" = true ]; then
        echo "LSF_ADDON_HOSTS=\"${mgmt_hostnames}\"" >> $LSF_CONF/lsf.conf
        create_appcenter_database
        sed -i "s/NoVNCProxyHost=.*/NoVNCProxyHost=pac.${dns_domain}/g" "$LSF_SUITE_GUI_CONF/pmc.conf"
        sed -i "s|<restHost>.*</restHost>|<restHost>${mgmt_hostname_primary}</restHost>|" $LSF_SUITE_GUI_CONF/pnc-config.xml
        sed -i "s|<wsHost>.*</wsHost>|<wsHost>pac.${dns_domain}</wsHost>|" $LSF_SUITE_GUI_CONF/pnc-config.xml
      else
        #echo "LSF_ADDON_HOSTS=$HOSTNAME" >> $LSF_CONF/lsf.conf
        sed -i 's/NoVNCProxyHost=.*/NoVNCProxyHost=localhost/g' "$LSF_SUITE_GUI_CONF/pmc.conf"
        sed -i "s|<restHost>.*</restHost>|<restHost>${mgmt_hostname_primary}</restHost>|" $LSF_SUITE_GUI_CONF/pnc-config.xml
        sed -i "s|<wsHost>.*</wsHost>|<wsHost>localhost</wsHost>|" $LSF_SUITE_GUI_CONF/pnc-config.xml
      fi
    fi

    echo "source $LSF_SUITE_TOP/ext/profile.platform" >> ~/.bashrc
    echo "source $LSF_SUITE_TOP/ext/profile.platform" >> "${lsfadmin_home_dir}"/.bashrc
    rm -rf $LSF_SUITE_GUI/3.0/bin/novnc.pem
    source ~/.bashrc

    perfadmin start all; sleep 5; perfadmin list
    sleep 10
    pmcadmin start; pmcadmin list

    appcenter_status=$(pmcadmin list | grep "WEBGUI" | awk '{print $2}')
    if [ "$appcenter_status" = "STARTED" ]; then
      echo "Application Center installation completed..."
    else
      echo "Application Center installation failed..."
    fi
  fi
fi



if [ "$do_app_center" = true ] && [ "${solution}" = "hpc" ]; then
  # Start all the PerfMonitor and WEBUI processes.
  source ~/.bashrc
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

# Check if LDAP configuration is enabled
if [ "$enable_ldap" = "true" ]; then

    # Extract and store the major version of the operating system (8 or 9)
    version=$(grep -oE 'release [0-9]+' /etc/redhat-release | awk '{print $2}')

    # Proceed if the detected version is either 8 or 9
    if [ "$version" == "8" ] || [ "$version" == "9" ]; then
        echo "Detected as RHEL or Rocky $version. Proceeding with LDAP client configuration..."

        # Enable password authentication for SSH by modifying the configuration file
        sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
        systemctl restart sshd

        # Check if the SSL certificate file exists, then copy it to the correct location
        # Retry finding SSL certificate with a maximum of 5 attempts and 5 seconds sleep between retries
        for attempt in {1..5}; do
            if [ -f "/mnt/lsf/openldap/ldap_cacert.pem" ]; then
                echo "LDAP SSL cert found under /mnt/lsf/openldap/ldap_cacert.pem path"
                mkdir -p /etc/openldap/certs
                cp -pr /mnt/lsf/openldap/ldap_cacert.pem /etc/openldap/certs/ldap_cacert.pem
                break
            else
                echo "SSL cert not found on attempt $attempt. Retrying in 5 seconds..."
                sleep 5
            fi
        done
        # Exit if the SSL certificate is still not found after 5 attempts
        [ -f "/mnt/lsf/openldap/ldap_cacert.pem" ] || { echo "SSL cert not found after 5 attempts. Exiting."; exit 1; }

        # Create and configure the SSSD configuration file for LDAP integration
        cat <<EOF > /etc/sssd/sssd.conf
[sssd]
config_file_version = 2
services = nss, pam, autofs
domains = default

[nss]
homedir_substring = /home

[pam]

[domain/default]
id_provider = ldap
autofs_provider = ldap
auth_provider = ldap
chpass_provider = ldap
ldap_uri = ldap://${ldap_server_ip}
ldap_search_base = dc=${base_dn%%.*},dc=${base_dn#*.}
ldap_id_use_start_tls = True
ldap_tls_cacertdir = /etc/openldap/certs
cache_credentials = True
ldap_tls_reqcert = allow
EOF

        # Secure the SSSD configuration file by setting appropriate permissions
        chmod 600 /etc/sssd/sssd.conf
        chown root:root /etc/sssd/sssd.conf

        # Create and configure the OpenLDAP configuration file for TLS
        cat <<EOF > /etc/openldap/ldap.conf
BASE dc=${base_dn%%.*},dc=${base_dn#*.}
URI ldap://${ldap_server_ip}
TLS_CACERT /etc/openldap/certs/ldap_cacert.pem
TLS_CACERTDIR /etc/openldap/certs
EOF

        # Rehash certificates in the OpenLDAP directory to ensure proper recognition
        openssl rehash /etc/openldap/certs

        # Apply the SSSD and home directory creation configuration using authselect
        authselect select sssd with-mkhomedir --force

        # Enable and start the SSSD and oddjobd services for user authentication and home directory management
        systemctl enable --now sssd oddjobd

        # Restart both services to apply the configuration
        systemctl restart sssd oddjobd

        # Validate the LDAP configuration by performing a test search using ldapsearch
        if ldapsearch -x -H ldap://"${ldap_server_ip}"/ -b "dc=${base_dn%%.*},dc=${base_dn#*.}" > /dev/null; then
            echo "LDAP configuration completed successfully!"
        else
            echo "LDAP configuration failed! Exiting."
            exit 1
        fi

        # Ensure LSF commands are available to all users by adding the profile to bashrc
        echo ". ${LSF_CONF}/profile.lsf" >> /etc/bashrc
        source /etc/bashrc

    else
        # Exit if an unsupported RHEL version is detected
        echo "This script is designed for RHEL 8 or 9. Detected version: $version. Exiting."
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
if [ "$observability_monitoring_enable" = true ]; then

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

# Setting up the IBM Cloud Logs
if [ "$observability_logs_enable_for_management" = true ]; then

  echo "Configuring cloud logs for management since observability logs for management is enabled"
  sudo cp /root/post-config.sh /opt/ibm
  cd /opt/ibm

  cat <<EOL > /etc/fluent-bit/fluent-bit.conf
[SERVICE]
  Flush                   1
  Log_Level               info
  Daemon                  off
  Parsers_File            parsers.conf
  Plugins_File            plugins.conf
  HTTP_Server             On
  HTTP_Listen             0.0.0.0
  HTTP_Port               9090
  Health_Check            On
  HC_Errors_Count         1
  HC_Retry_Failure_Count  1
  HC_Period               30
  storage.path            /fluent-bit/cache
  storage.max_chunks_up   192
  storage.metrics         On

[INPUT]
  Name                syslog
  Path                /tmp/in_syslog
  Buffer_Chunk_Size   32000
  Buffer_Max_Size     64000
  Receive_Buffer_Size 512000

[INPUT]
  Name              tail
  Tag               *
  Path              /opt/ibm/lsf/log/*.log
  Path_Key          file
  Exclude_Path      /var/log/at/**
  DB                /opt/ibm/lsf/log/fluent-bit.DB
  Buffer_Chunk_Size 32KB
  Buffer_Max_Size   256KB
  Skip_Long_Lines   On
  Refresh_Interval  10
  storage.type      filesystem
  storage.pause_on_chunks_overlimit on

[FILTER]
  Name modify
  Match *
  Add subsystemName management
  Add applicationName lsf

@INCLUDE output-logs-router-agent.conf
EOL

  sudo chmod +x post-config.sh
  sudo ./post-config.sh -h $cloud_logs_ingress_private_endpoint -p "3443" -t "/logs/v1/singles" -a IAMAPIKey -k $VPC_APIKEY_VALUE --send-directly-to-icl -s true -i Production
  sudo echo "2024-10-16T14:31:16+0000 INFO Testing IBM Cloud LSF Logs from management: $this_hostname" >> /opt/ibm/lsf/log/test.log
  sudo logger -u /tmp/in_syslog my_ident my_syslog_test_message_from_management:$this_hostname

else
  echo "Cloud Logs configuration skipped since observability logs for management is not enabled"
fi

echo "END $(date '+%Y-%m-%d %H:%M:%S')"
sleep 0.1 # don't race against the log
