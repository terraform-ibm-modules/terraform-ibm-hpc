#!/bin/bash

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
  useradd lsfadmin
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
  useradd -u 1005 -m lsfadmin
  chage -I -1 -m 0 -M 99999 -E -1 -W 14 lsfadmin
  chage -I -1 -m 0 -M 99999 -E -1 -W 14 vpcuser
  id lsfadmin
  echo 'lsfadmin ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers #pragma: allowlist secret
fi

# LSF prerequisites packages required for configuring and installing LSF
LSF_TOP="/opt/ibm/lsf"
LSF_CONF_PATH="${LSF_TOP}/conf"
LSF_PACKAGES_PATH="/tmp/packages"
echo $LSF_PACKAGES_PATH
mkdir -p ${LSF_TOP}
chmod -R 755 /opt

echo "======================Triggering mounting of Cos Bucket====================="
mkdir /wes-hpc
s3fs custom-image-builder /wes-hpc -o url=https://s3.direct.us-south.cloud-object-storage.appdomain.cloud -o ro -o public_bucket=1
mkdir -p /tmp/packages
cp -r /wes-hpc/lsf/* /tmp/packages/
ls -ltr /tmp/packages/
echo "======================Cos Bucket mounting completed====================="

sleep 100

echo "======================Installation of IBMCloud Plugins started====================="
curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
pip3 install ibm-vpc==0.10.0
pip3 install ibm-cloud-networking-services ibm-cloud-sdk-core selinux
ibmcloud plugin install vpc-infrastructure DNS
echo "======================Installation of IBMCloud Plugins completed====================="


hostnamectl
hostnamectl set-hostname lsfservers
# Installation of LSF base packages on compute node
cd "${LSF_PACKAGES_PATH}" || exit
yum install -y --nogpgcheck "${LSF_PACKAGES_PATH}"/lsf-conf-10.1.0.15-25100715.noarch.rpm
yum install -y --nogpgcheck "${LSF_PACKAGES_PATH}"/lsf-man-pages-10.1.0.15-25100715.noarch.rpm
yum install -y --nogpgcheck "${LSF_PACKAGES_PATH}"/lsf-client-10.1.0.15-25100715.x86_64.rpm
yum install -y --nogpgcheck "${LSF_PACKAGES_PATH}"/lsf-server-10.1.0.15-25100715.x86_64.rpm
yum install -y --nogpgcheck "${LSF_PACKAGES_PATH}"/lsf-integrations-10.1.0.15-25100715.x86_64.rpm
yum install -y --nogpgcheck "${LSF_PACKAGES_PATH}"/lsf-ego-server-10.1.0.15-25100715.x86_64.rpm
yum install -y --nogpgcheck "${LSF_PACKAGES_PATH}"/lsf-devel-10.1.0.15-25100715.x86_64.rpm
yum install -y --nogpgcheck "${LSF_PACKAGES_PATH}"/lsf-data-mgr-10.1.0.15-25100715.x86_64.rpm
yum install -y --nogpgcheck "${LSF_PACKAGES_PATH}"/lsf-ls-client-10.1.0.15-25100715.x86_64.rpm
yum install -y --nogpgcheck "${LSF_PACKAGES_PATH}"/ibm-jre-1.8.0-25070916.x86_64.rpm
yum install -y --nogpgcheck "${LSF_PACKAGES_PATH}"/lsf-pm-client-10.2.0.15-25100715.x86_64.rpm
echo "========================LSF 10.1 installation completed====================="

# Installation Of OpenMPI
cd "${LSF_PACKAGES_PATH}" || exit
wget https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-4.1.0.tar.gz
tar -xvf openmpi-4.1.0.tar.gz
cd openmpi-4.1.0 || exit
ln -s /usr/lib64/libnsl.so.2.0.0 /usr/lib64/libnsl.so
export LANG=C
./configure --prefix='/usr/local/openmpi-4.1.0' --enable-mpi-thread-multiple --enable-shared --disable-static --enable-mpi-fortran=usempi --disable-libompitrace --enable-script-wrapper-compilers --enable-wrapper-rpath --enable-orterun-prefix-by-default --with-io-romio-flags=--with-file-system=nfs --with-lsf=/opt/ibm/lsf/10.1 --with-lsf-libdir=/opt/ibm/lsf/10.1/linux3.10-glibc2.17-x86_64/lib
make -j 32
make install
find /usr/local/openmpi-4.1.0/ -type d -exec chmod 775 {} \;
echo "======================OneMPI installation completed====================="

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

# Setting up access to the appropriate path
mv -f ${LSF_PACKAGES_PATH}/*.entitlement /opt/ibm/lsf/conf
chown -R lsfadmin:root ${LSF_CONF_PATH}

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

#Cloud Log Agent Installation
echo "Cloud logs agent installation started"
pwd
wget https://logs-router-agent-install-packages.s3.us.cloud-object-storage.appdomain.cloud/logs-router-agent-rhel8-1.3.1.rpm.sha256
wget https://logs-router-agent-install-packages.s3.us.cloud-object-storage.appdomain.cloud/logs-router-agent-rhel8-1.3.1.rpm
sha256sum -c logs-router-agent-rhel8-1.3.1.rpm.sha256
rpm -ivh logs-router-agent-rhel8-1.3.1.rpm
rpm -qa | grep logs-router-agent
wget -O /root/post-config.sh https://logs-router-agent-config.s3.us.cloud-object-storage.appdomain.cloud/post-config.sh
ls -a /root
echo "Cloud logs agent installated"

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
  history -c
