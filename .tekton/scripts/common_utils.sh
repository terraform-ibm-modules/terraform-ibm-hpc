#!/bin/bash
echo "************************************************"
get_commit_ssh_key() {
    CICD_SSH_KEY=cicd
    REVISION=$1
    if [ "${REVISION}" ]; then
    CICD_SSH_KEY=$(echo $CICD_SSH_KEY-"$REVISION")
    else
    CICD_SSH_KEY=$CICD_SSH_KEY-tekton
    fi
}

get_pr_ssh_key() {
    PR_REVISION=$1
    CICD_SSH_KEY=cicd
    CICD_SSH_KEY=$(echo $CICD_SSH_KEY-"$PR_REVISION")
}

git clone --depth=1 https://github.com/tfutils/tfenv.git ~/.tfenv
echo "export PATH=$PATH:$HOME/.tfenv/bin" >> ~/.bashrc
ln -s ~/.tfenv/bin/* /usr/local/bin
tfenv install 1.5.7
tfenv use 1.5.7
terraform --version

cd "$(pwd)"/ &&
echo "export PATH=\$PATH:$(pwd)/go/bin:\$HOME/go/bin" >> ~/.bashrc &&
echo "export GOROOT=$(pwd)/go" >> ~/.bashrc
# shellcheck source=/dev/null.
source ~/.bashrc
go version

python3 -m pip install --upgrade pip
python3 -m pip install --pre --upgrade requests==2.20.0
python3 -m pip install --pre --upgrade ibm-cos-sdk==2.0.1

echo "************************************************"
