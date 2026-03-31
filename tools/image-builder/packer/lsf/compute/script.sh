#!/bin/bash

SUMMARY_FILE="/var/log/hpc_summary.log"

{
    echo "========== HPC IMAGE SUMMARY =========="
    echo "Generated on: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Host: $(hostname)"
    echo ""
    echo "NOTE:"
    echo "- This report covers default image setup (script.sh)"
    echo "- Customizations from customer_script.sh are NOT included"
    echo ""
    printf "%-8s | %-20s | %s\n" "STATUS" "COMPONENT" "DETAILS"
    echo "-------------------------------------------------------"
} > "$SUMMARY_FILE"
chmod 644 "$SUMMARY_FILE"

log_summary() {
    local status="$1"
    local component="$2"
    local message="$3"

    printf "%-8s | %-20s | %s\n" "$status" "$component" "$message" >> "$SUMMARY_FILE"
}


# ---------------- Verification Functions ----------------

verify_s3fs() {
    command -v s3fs >/dev/null 2>&1
}

verify_python() {
    python3 --version >/dev/null 2>&1
}

verify_pip() {
    pip3 -V >/dev/null 2>&1
}

verify_user() {
    id "$1" >/dev/null 2>&1
}

verify_mount() {
    mount | grep "$1" >/dev/null 2>&1
}

verify_directory_nonempty() {
    [ -d "$1" ] && [ "$(ls -A "$1")" ]
}

verify_ibmcloud() {
    command -v ibmcloud >/dev/null 2>&1
}

verify_ibm_plugin() {
    ibmcloud plugin list 2>/dev/null | grep -i "$1" >/dev/null 2>&1
}

verify_python_package() {
    pip3 show "$1" >/dev/null 2>&1
}

verify_file() {
    [ -f "$1" ]
}

verify_hostname() {
    hostnamectl | grep "$1" >/dev/null 2>&1
}

verify_lsf() {
    [ -d "/opt/ibm/lsf" ] && [ -f "/opt/ibm/lsf/conf/lsf.conf" ]
}

verify_lsf_commands() {
    command -v bsub >/dev/null 2>&1
}

verify_license_scheduler() {
    ls /opt/ibm/lsf/conf | grep -i license >/dev/null 2>&1
}

verify_file_contains() {
    grep -q "$2" "$1" 2>/dev/null
}

verify_openmpi() {
    [ -x "/usr/local/openmpi-5.0.9/bin/mpirun" ]
}

verify_oneapi() {
    [ -d "/opt/intel/oneapi" ]
}

verify_entitlement_moved() {
    [ -f "/opt/ibm/lsf/conf/lsf.entitlement" ]
}

verify_sysdig() {
    systemctl list-unit-files | grep dragent >/dev/null 2>&1
}

verify_log_agent() {
    rpm -qa | grep logs-router-agent >/dev/null 2>&1
}

verify_cleanup() {
    [ ! -d "$LSF_PACKAGES_PATH" ]
}

install_with_retry() {
    local cmd="$1"
    local retries="$2"
    local count=0

    until $cmd || [ $count -eq "$retries" ]; do
        echo "Installation failed. Retrying..."
        sleep 5  # Adjust sleep duration between retries as needed
        count=$((count + 1))
    done

    if [ $count -eq "$retries" ]; then
        echo "Failed to install after $retries attempts. Exiting."
        exit 1
    fi
}

disable_cnf_update_db_hook() {
    if grep -q 'APT::Update::Post-Invoke-Success' /etc/apt/apt.conf.d/*; then
        sudo sed -i '/APT::Update::Post-Invoke-Success/d' /etc/apt/apt.conf.d/*
    fi
}

add_sysdig_gpg_key() {
    wget -qO - https://download.sysdig.com/stable/deb/sysdig.gpg.key | sudo tee /etc/apt/trusted.gpg.d/sysdig.gpg > /dev/null
}

# Installation of S3fs packages for mounting the cos buckets
if grep -q 'ID="rhel"' /etc/os-release || grep -q 'ID="rocky"' /etc/os-release; then

  sudo rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-8
  sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

  install_with_retry "sudo yum install -y s3fs-fuse" 3

  rpm -qa | grep epel-release
  rpm -qa | grep s3fs-fuse

  yum install -y python3.11 python3.11-pip ed wget gcc-c++ gcc-gfortran kernel-devel-"$(uname -r)" perl libnsl openldap-clients nss-pam-ldapd sssd tar

  useradd -u 1005 -m lsfadmin
  chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin
  chage -I -1 -m 0 -M 99999 -E -1 -W 14 vpcuser
  id lsfadmin

  echo 'lsfadmin ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers #pragma: allowlist secret

  rm -f /usr/bin/python3
  rm -rf /bin/pip3
  ln -s /usr/bin/python3.11 /usr/bin/python3
  ln -s /usr/bin/pip3.11 /bin/pip3

  python3 --version
  pip3 -V

else

  sudo add-apt-repository -y ppa:deadsnakes/ppa;
  sudo apt update
  disable_cnf_update_db_hook
  add_sysdig_gpg_key

  apt install -y s3fs
  dpkg -l | grep s3fs
  apt install -y python3.11 g++ libelf-dev linux-headers-"$(uname -r)" gfortran libopenmpi-dev python3-pip sssd libpam-sss libnss-sss

  rm -f /usr/bin/python3
  ln -s /usr/bin/python3.11 /usr/bin/python3

  python3 --version
  pip3 -V

  adduser --disabled-password --gecos "" lsfadmin
  echo 'lsfadmin ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers #pragma: allowlist secret
  usermod -s /bin/bash lsfadmin

fi

# S3FS
if verify_s3fs; then
    version=$(s3fs --version 2>/dev/null | head -n1)
    log_summary "SUCCESS" "S3FS" "${version:-Installed}"
else
    log_summary "FAILED" "S3FS" "Not available"
fi

# Python
if verify_python; then
    version=$(python3 --version 2>&1)
    log_summary "SUCCESS" "Python" "$version"
else
    log_summary "FAILED" "Python" "Not available"
fi

# Pip
if verify_pip; then
    version=$(pip3 -V 2>&1)
    log_summary "SUCCESS" "Pip" "$version"
else
    log_summary "FAILED" "Pip" "Not available"
fi

# User check
if verify_user "lsfadmin"; then
    log_summary "SUCCESS" "User lsfadmin" "Created successfully"
else
    log_summary "FAILED" "User lsfadmin" "Not found"
fi

# LSF prerequisites packages required for configuring and installing LSF
LSF_TOP="/opt/ibm/lsf"
LSF_CONF_PATH="${LSF_TOP}/conf"
LSF_PACKAGES_PATH="/tmp/packages"
echo $LSF_PACKAGES_PATH
mkdir -p ${LSF_TOP}
chmod -R 755 /opt

echo "======================Triggering mounting of Cos Bucket for lsf package installation====================="
mkdir /wes-hpc
echo "list /wes-hpc"
ls -ltr /wes-hpc
s3fs custom-image-builder-bucket /wes-hpc -o url=https://s3.direct.us-south.cloud-object-storage.appdomain.cloud -o ro -o public_bucket=1
echo "list /wes-hpc after mounting"
ls -ltr /wes-hpc
mkdir -p /tmp/packages
cp -r /wes-hpc/lsf/LSF_Standalone_Packages/* /tmp/packages/
echo "list /tmp/packages/ after copying"
ls -ltr /tmp/packages/
echo "======================Cos Bucket mounting completed for lsf package installation====================="

sleep 100

# COS Mount
if verify_mount "/wes-hpc"; then
    log_summary "SUCCESS" "COS Mount" "/wes-hpc mounted"
else
    log_summary "FAILED" "COS Mount" "Mount failed"
fi

# LSF Packages copied
if verify_directory_nonempty "/tmp/packages"; then
    count=$(ls /tmp/packages | wc -l)
    log_summary "SUCCESS" "LSF Packages" "$count files available"
else
    log_summary "FAILED" "LSF Packages" "No packages found"
fi

echo "======================Installation of IBMCloud Plugins started====================="
curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
export PATH=$PATH:/usr/local/ibmcloud/bin
pip3 install ibm-vpc==0.10.0
pip3 install ibm-cloud-networking-services ibm-cloud-sdk-core selinux
ibmcloud plugin install vpc-infrastructure DNS
echo "======================Installation of IBMCloud Plugins completed====================="

# IBM Cloud CLI
if verify_ibmcloud; then
    version=$(ibmcloud --version 2>/dev/null | head -n1)
    log_summary "SUCCESS" "IBM Cloud CLI" "$version"
else
    log_summary "FAILED" "IBM Cloud CLI" "Not installed"
fi

# IBM Cloud Plugins
if verify_ibm_plugin "vpc-infrastructure"; then
    log_summary "SUCCESS" "IBM Plugin VPC" "Installed"
else
    log_summary "FAILED" "IBM Plugin VPC" "Missing"
fi

if verify_ibm_plugin "DNS"; then
    log_summary "SUCCESS" "IBM Plugin DNS" "Installed"
else
    log_summary "FAILED" "IBM Plugin DNS" "Missing"
fi

# Python SDKs
if verify_python_package "ibm-vpc"; then
    version=$(pip3 show ibm-vpc | grep Version | awk '{print $2}')
    log_summary "SUCCESS" "ibm-vpc SDK" "Version $version"
else
    log_summary "FAILED" "ibm-vpc SDK" "Not installed"
fi

if verify_python_package "ibm-cloud-networking-services"; then
    log_summary "SUCCESS" "Networking SDK" "Installed"
else
    log_summary "FAILED" "Networking SDK" "Missing"
fi

hostnamectl
hostnamectl set-hostname lsfservers

# Hostname
if verify_hostname "lsfservers"; then
    log_summary "SUCCESS" "Hostname" "Set to lsfservers"
else
    log_summary "FAILED" "Hostname" "Not set correctly"
fi

echo "====== Setting entitlement files ======"
echo 'LS_Standard  10.1  ()  ()  ()  ()  18b1928f13939bd17bf25e09a2dd8459f238028f' > /tmp/packages/ls.entitlement
echo 'LSF_Standard  10.1  ()  ()  ()  pa  3f08e215230ffe4608213630cd5ef1d8c9b4dfea' > /tmp/packages/lsf.entitlement

# Entitlement files
if verify_file "/tmp/packages/ls.entitlement" && verify_file "/tmp/packages/lsf.entitlement"; then
    log_summary "SUCCESS" "Entitlement Files" "Created"
else
    log_summary "FAILED" "Entitlement Files" "Missing"
fi

echo "======================LSF installation====================="
cd $LSF_PACKAGES_PATH || exit
zcat lsf*lsfinstall_linux_x86_64.tar.Z | tar xvf -
cd lsf*_lsfinstall || exit
sed -e '/show_copyright/ s/^#*/#/' -i lsfinstall
cat <<EOT >> install.config
LSF_TOP="/opt/ibm/lsf"
LSF_ADMINS="lsfadmin"
LSF_CLUSTER_NAME="HPCCluster"
LSF_LOCAL_RESOURCES="[resource icgen2host]"
LSF_MASTER_LIST="lsfservers"
LSF_ENTITLEMENT_FILE="$LSF_PACKAGES_PATH/lsf.entitlement"
CONFIGURATION_TEMPLATE="DEFAULT"
ENABLE_DYNAMIC_HOSTS="Y"
ENABLE_EGO="N"
ACCEPT_LICENSE="Y"
SILENT_INSTALL="Y"
LSF_SILENT_INSTALL_TARLIST="ALL"
EOT
bash lsfinstall -f install.config
echo $?
cat Install.log
echo "====================== LSF Setup Done====================="

# LSF Core Install
if verify_lsf; then
    log_summary "SUCCESS" "LSF Core" "/opt/ibm/lsf present"
else
    log_summary "FAILED" "LSF Core" "Installation missing"
fi

echo "====== LSF License Scheduler installation started  ======"
# LSF License Scheduler installation
source /opt/ibm/lsf/conf/profile.lsf
cd $LSF_PACKAGES_PATH || exit

if verify_lsf_commands; then
    version=$(lsid 2>/dev/null | head -n1)
    log_summary "SUCCESS" "LSF Commands" "${version:-Available}"
else
    log_summary "FAILED" "LSF Commands" "bsub not working"
fi

echo "====== Decompressing, extracting and installing the LSF License Scheduler packages  ======"
zcat lsf*_licsched_lnx418-x64.tar.Z | tar xvf -
cd lsf*_licsched_linux4.18-glibc2.28-x86_64 || exit
# Edit the config file
cat <<EOF >> setup.config
LS_TOP="/opt/ibm/lsf"
LS_ADMIN="lsfadmin"
SILENT_INSTALL="Y"
EOF
bash setup
echo $?
echo "====== Installation ends  ======"
echo "====== Checking for License Scheduler files  ======"
cd /opt/ibm/lsf/conf || exit
echo 'LSF_LICENSE_ACCT_PATH=/opt/ibm/lsf/work' >> lsf.conf #pragma: allowlist secret
ls -ltr
echo "====== LSF License Scheduler installation completed ======"

# License Scheduler
if verify_license_scheduler; then
    log_summary "SUCCESS" "License Scheduler" "Configured"
else
    log_summary "FAILED" "License Scheduler" "Missing"
fi

# LSF Config Update
if verify_file_contains "/opt/ibm/lsf/conf/lsf.conf" "LSF_LICENSE_ACCT_PATH"; then
    log_summary "SUCCESS" "LSF Config" "License path set"
else
    log_summary "FAILED" "LSF Config" "License path missing"
fi

echo "====== AMD and Intel HostModel Configuration started ======"
cd /opt/ibm/lsf/conf || exit
sed -i '/^Intel_EM64T/a Intel_GraniteRapids 50.0 (x6_5000_IntelXeonProcessorGraniteRapids)' lsf.shared
sed -i '/^Intel_EM64T/a Intel_Cascadelake 48.0 (x6_4788_IntelXeonProcessorCascadelake)' lsf.shared
sed -i '/^Intel_EM64T/a Intel_SapphireRapids 42.0 (x6_4200_IntelXeonProcessorSapphireRapids)' lsf.shared
sed -i '/^Intel_EM64T/a AMD_EPYC_9575F 66.0 (x26_6590_AMDEPYC9575F64CoreProcessor)' lsf.shared
sed -i '/^Intel_EM64T/a Intel_Gaudi_PLATINUM_8568Y 46.0 (x6_4600_IntelXeonPLATINUM8568Y+)' lsf.shared
echo "====== AMD and Intel HostModel Configuration completed ======"

# Host Model Config
if verify_file_contains "/opt/ibm/lsf/conf/lsf.shared" "AMD_EPYC_9575F"; then
    log_summary "SUCCESS" "Host Models" "Custom models added"
else
    log_summary "FAILED" "Host Models" "Not configured"
fi

# Installation Of OpenMPI
echo "====== SetUp of one MPI Started ======"
cd "$LSF_PACKAGES_PATH" || exit
wget https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-5.0.9.tar.gz
tar -xvf openmpi-5.0.9.tar.gz
cd openmpi-5.0.9 || exit
ln -s /usr/lib64/libnsl.so.2.0.0 /usr/lib64/libnsl.so
export LANG=C
#Please update the linux package latest version in the below line whenever required
./configure --prefix='/usr/local/openmpi-5.0.9' --enable-shared --disable-static --enable-mpi-fortran=usempi --disable-libompitrace --enable-script-wrapper-compilers --enable-wrapper-rpath --enable-prte-prefix-by-default --with-io-romio-flags=--with-file-system=nfs --with-lsf=/opt/ibm/lsf/10.1 --with-lsf-libdir=/opt/ibm/lsf/10.1/linux4.18-glibc2.28-x86_64/lib
make -j "$(nproc)"
make install
find /usr/local/openmpi-5.0.9/ -type d -exec chmod 775 {} \;
echo "======================OneMPI installation completed====================="

# OpenMPI
if verify_openmpi; then
    version=$(/usr/local/openmpi-5.0.9/bin/mpirun --version 2>/dev/null | head -n1)
    log_summary "SUCCESS" "OpenMPI" "${version:-Installed} (path: /usr/local/openmpi-5.0.9)"
else
    log_summary "FAILED" "OpenMPI" "Not installed"
fi

echo "====== SetUp of Intel One API Started ======"
# Intel One API (hpckit) installation based on the Operating system
if grep -q 'ID="rhel"' /etc/os-release || grep -q 'ID="rocky"' /etc/os-release; then
  # For RHEL-based systems
  cat << EOF | sudo tee /etc/yum.repos.d/oneAPI.repo
[oneAPI]
name=Intel® oneAPI repository
baseurl=https://yum.repos.intel.com/oneapi
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
EOF
  sudo yum install -y intel-basekit intel-hpckit
  rpm -qa | grep -E "intel-hpckit|intel-basekit"
  sudo rm -rf /etc/yum.repos.d/oneAPI.repo
  ls /etc/yum.repos.d
  # Updating security check
  yum update --security -y
else
  # For Ubuntu-based systems
  wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list
  sudo apt update
  sudo apt install -y intel-basekit intel-hpckit
  sudo rm -rf /etc/apt/sources.list.d/oneAPI.list
  ls /etc/apt/sources.list.d
  # Verify the installation
  dpkg -l | grep -E "intel-basekit|intel-hpckit"
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y nfs-common build-essential
fi
echo "====== SetUp of Intel one API completed ======"

# Intel oneAPI
if verify_oneapi; then
    log_summary "SUCCESS" "Intel oneAPI" "Installed at /opt/intel/oneapi"
else
    log_summary "FAILED" "Intel oneAPI" "Not installed"
fi

# oneAPI Compiler (actual usability check)
comp_path=$(find /opt/intel/oneapi/compiler -type f -name icx 2>/dev/null | head -n1)

if [ -x "$comp_path" ]; then
    version=$("$comp_path" --version 2>/dev/null | head -n1)
    log_summary "SUCCESS" "Intel Compiler" "$version (path: $comp_path, setvars.sh required)"
else
    log_summary "FAILED" "Intel Compiler" "Binary not found under /opt/intel/oneapi"
fi

# Setting up access to the appropriate path
mv -f ${LSF_PACKAGES_PATH}/*.entitlement /opt/ibm/lsf/conf
chown -R lsfadmin:root ${LSF_CONF_PATH}

# Entitlement moved
if verify_entitlement_moved; then
    log_summary "SUCCESS" "Entitlement Move" "Moved to LSF conf"
else
    log_summary "FAILED" "Entitlement Move" "Missing in target"
fi

echo "====== Sysdig Agent installation Started ======"
echo "${INSTALL_SYSDIG}"
if [ "${INSTALL_SYSDIG}" = true ]; then
   # Installation of Sysdig Agent on compute nodes
   echo "Installation of Sysdig Agent started"
   curl -sL https://ibm.biz/install-sysdig-agent | sudo bash -s -- --access_key ==ACCESSKEY== --collector ==COLLECTOR== --collector_port 6443 --secure true --check_certificate false --additional_conf 'sysdig_capture_enabled: false\nremotefs: true\nfeature:\n mode: monitor_light'
   systemctl stop dragent
   systemctl disable dragent
else
  echo "INSTALL_SYDIG is set as false and the sysdig agent is not installed on compute node image"
fi

# Sysdig Agent (conditional)
if [ "${INSTALL_SYSDIG}" = true ]; then
    if verify_sysdig; then
        log_summary "SUCCESS" "Sysdig Agent" "Installed"
    else
        log_summary "FAILED" "Sysdig Agent" "Install failed"
    fi
else
    log_summary "SKIPPED" "Sysdig Agent" "Disabled by config"
fi

echo "====== Sysdig Agent installation completed ======"

#Cloud Log Agent Installation
echo "====== Cloud Log Agent Installation started ======"
pwd
wget https://logs-router-agent-install-packages.s3.us.cloud-object-storage.appdomain.cloud/logs-router-agent-rhel8-1.7.1.rpm.sha256
wget https://logs-router-agent-install-packages.s3.us.cloud-object-storage.appdomain.cloud/logs-router-agent-rhel8-1.7.1.rpm
sha256sum -c logs-router-agent-rhel8-1.7.1.rpm.sha256
rpm -ivh logs-router-agent-rhel8-1.7.1.rpm
rpm -qa | grep logs-router-agent
wget -O /root/post-config.sh https://logs-router-agent-config.s3.us.cloud-object-storage.appdomain.cloud/post-config.sh
ls -a /root
echo "====== Cloud Log Agent Installation completed ======"

# Cloud Log Agent
if verify_log_agent; then
    log_summary "SUCCESS" "Log Agent" "Installed"
else
    log_summary "FAILED" "Log Agent" "Not installed"
fi

# Security approach to delete unwanted ssh keys and host file entries
rm -rf "${LSF_PACKAGES_PATH}"
if grep -q 'ID="rhel"' /etc/os-release || grep -q 'ID="rocky"' /etc/os-release; then
  rm -rf /home/vpcuser/.ssh/authorized_keys
  rm -rf /home/vpcuser/.ssh/known_hosts
  rm -rf /home/vpcuser/.ssh/id_rsa*
else
  rm -rf /home/ubuntu/.ssh/authorized_keys
  rm -rf /home/ubuntu/.ssh/known_hosts
  rm -rf /home/ubuntu/.ssh/id_rsa*
fi
rm -rf /home/lsfadmin/.ssh/authorized_keys
rm -rf /home/lsfadmin/.ssh/known_hosts
rm -rf /home/lsfadmin/.ssh/id_rsa*
rm -rf /root/.ssh/authorized_keys
rm -rf /root/.ssh/known_hosts
rm -rf /root/.ssh/id_rsa*
systemctl stop syslog
rm -rf /var/log/messages
rm -rf /root/.bash_history

# Cleanup
if verify_cleanup; then
    log_summary "SUCCESS" "Cleanup" "Temporary files removed"
else
    log_summary "FAILED" "Cleanup" "Residual files present"
fi

log_summary "INFO" "Customer Script" "Not validated or tracked in this report"

echo "=======================================================" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "---- End of Base Image Setup (script.sh) ----" >> "$SUMMARY_FILE"
echo "---- Customer Script (customer_script.sh) not tracked ----" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

cat "$SUMMARY_FILE"

history -c

