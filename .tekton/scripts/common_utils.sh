#!/bin/bash
echo "************************************************"
get_commit_ssh_key() {
    REVISION=$1
    CHECK_SOLUTION=$2
    LSF_VERSION=$3
    if [[ "$CHECK_SOLUTION" == "hpcaas" ]]; then
        CICD_SSH_KEY=cicd-hpcaas
        if [ "${REVISION}" ]; then
            CICD_SSH_KEY=$(echo $CICD_SSH_KEY-"$REVISION")
        else
            CICD_SSH_KEY=$CICD_SSH_KEY-tekton
        fi
    fi
    if [[ "$CHECK_SOLUTION" == "lsf" ]]; then
        CICD_SSH_KEY=cicd-lsf
        if [ "${REVISION}" ]; then
            CICD_SSH_KEY=$(echo $CICD_SSH_KEY-"$REVISION")
        else
            CICD_SSH_KEY=$CICD_SSH_KEY-tekton
        fi
    fi
    if [[ "$CHECK_SOLUTION" == "lsf-da" ]]; then
        CICD_SSH_KEY=cicd-"$LSF_VERSION"
        if [ "${REVISION}" ]; then
            CICD_SSH_KEY=$(echo $CICD_SSH_KEY-"$REVISION")
        else
            CICD_SSH_KEY=$CICD_SSH_KEY-tekton
        fi
    fi

}

get_pr_ssh_key() {
    PR_REVISION=$1
    CHECK_SOLUTION=$2
    LSF_VERSION=$3
    if [[ "$CHECK_SOLUTION" == "hpcaas" ]]; then
        CICD_SSH_KEY=cicd-hpcaas
        CICD_SSH_KEY=$(echo $CICD_SSH_KEY-"$PR_REVISION")
    fi
    if [[ "$CHECK_SOLUTION" == "lsf" ]]; then
        CICD_SSH_KEY=cicd-lsf
        CICD_SSH_KEY=$(echo $CICD_SSH_KEY-"$PR_REVISION")
    fi
    if [[ "$CHECK_SOLUTION" == "lsf-da" ]]; then
        CICD_SSH_KEY=cicd-"$LSF_VERSION"
        CICD_SSH_KEY=$(echo $CICD_SSH_KEY-"$PR_REVISION")
    fi
}

git clone --depth=1 https://github.com/tfutils/tfenv.git ~/.tfenv
echo "export PATH=$PATH:$HOME/.tfenv/bin" >>~/.bashrc
ln -s ~/.tfenv/bin/* /usr/local/bin
tfenv install latest
tfenv use latest
terraform --version

cd "$(pwd)"/ &&
    echo "export PATH=\$PATH:$(pwd)/go/bin:\$HOME/go/bin" >>~/.bashrc &&
    echo "export GOROOT=$(pwd)/go" >>~/.bashrc
# shellcheck source=/dev/null.
source ~/.bashrc
go version

# #######################################
# # Install Packages
# #######################################
curl -sS https://bootstrap.pypa.io/get-pip.py | python3
python3 -m pip install --upgrade pip --quiet
python3 -m pip install --ignore-installed requests==2.25.1
python3 -m pip install --pre --upgrade botocore --quiet
python3 -m pip install --pre --upgrade ibm-cloud-sdk-core --quiet
ibmcloud plugin install cloud-object-storage -f
ibmcloud plugin install vpc-infrastructure -f
ibmcloud plugin install dns -f
ibmcloud plugin install security-compliance -f
ibmcloud plugin install key-protect -r "IBM Cloud" -f
ibmcloud plugin install atracker -f
echo "************************************************"
