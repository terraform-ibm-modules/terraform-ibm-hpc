#!/bin/bash
set_ssh_key_name() {
    CHECK_SOLUTION=$1
    SSH_KEY_REGIONS=$2
    LSF_VERSION=$3
    # Convert to array using IFS (delimiter = comma)
    IFS=',' read -r -a REGIONS <<<"$SSH_KEY_REGIONS"
    # REGIONS=("jp-tok" "eu-de" "ca-tor")
    if [[ "$CHECK_SOLUTION" == "hpcaas" ]]; then
        CICD_SSH_KEY=cicd-hpcaas-"${BUILD_NUMBER:?}"
        if [ -z "${PR_REVISION}" ] && [ "${REVISION}" ]; then
            CICD_SSH_KEY=$(echo $CICD_SSH_KEY-"$REVISION")
        elif [ "${PR_REVISION}" ] && [ -z "${REVISION}" ]; then
            CICD_SSH_KEY=$(echo $CICD_SSH_KEY-"$PR_REVISION")
        else
            CICD_SSH_KEY=$CICD_SSH_KEY-tekton
        fi
    fi

    if [[ "$CHECK_SOLUTION" == "lsf" ]]; then
        CICD_SSH_KEY=cicd-lsf-"${BUILD_NUMBER:?}"
        if [ -z "${PR_REVISION}" ] && [ "${REVISION}" ]; then
            CICD_SSH_KEY=$(echo $CICD_SSH_KEY-"$REVISION")
        elif [ "${PR_REVISION}" ] && [ -z "${REVISION}" ]; then
            CICD_SSH_KEY=$(echo $CICD_SSH_KEY-"$PR_REVISION")
        else
            CICD_SSH_KEY=$CICD_SSH_KEY-tekton
        fi
    fi

    if [[ "$CHECK_SOLUTION" == "lsf-da" ]]; then
        CICD_SSH_KEY=cicd-"$LSF_VERSION"-"${BUILD_NUMBER:?}"
        if [ -z "${PR_REVISION}" ] && [ "${REVISION}" ]; then
            CICD_SSH_KEY=$(echo $CICD_SSH_KEY-"$REVISION")
        elif [ "${PR_REVISION}" ] && [ -z "${REVISION}" ]; then
            CICD_SSH_KEY=$(echo $CICD_SSH_KEY-"$PR_REVISION")
        else
            CICD_SSH_KEY=$CICD_SSH_KEY-tekton
        fi
    fi
}

ssh_key_create() {
    CHECK_SOLUTION=$1
    SSH_KEY_REGIONS=$2
    LSF_VERSION=$3

    set_ssh_key_name "${CHECK_SOLUTION}" "${SSH_KEY_REGIONS}" "${LSF_VERSION}" "${BUILD_NUMBER:?}"
    file=/artifacts/.ssh
    if [ ! -e "$file" ]; then
        echo "$file does not exist, creating ssh-key-pairs."
        mkdir /artifacts/.ssh
        ssh_key_pair=$(eval "ssh-keygen -t rsa -N '' -f /artifacts/.ssh/id_rsa <<< y")
        if echo "$ssh_key_pair" | grep -q "Generating public/private rsa key pair"; then
            echo "SSH-KEY pairs generated"
        else
            echo "Issue with creating ssh-key pairs $ssh_key_pair"
        fi
    else
        echo "$file exists, making use of it."
    fi

    # Looping all region to create SSH-KEYS
    for region in "${REGIONS[@]}"; do
        disable_update_check=$(eval "ibmcloud config --check-version=false")
        echo "$disable_update_check"
        auhtenticate=$(eval "ibmcloud login --apikey $API_KEY -r $region")
        if [[ $auhtenticate = *OK* ]]; then
            echo "************SSH-KEY creation process in $region ************"
            check_key=$(eval "ibmcloud is keys | grep $CICD_SSH_KEY | awk '{print $2}'")
            if [[ -z "$check_key" ]]; then
                echo "$CICD_SSH_KEY creating in $region"
                ssh_key_create=$(eval "ibmcloud is key-create $CICD_SSH_KEY @/artifacts/.ssh/id_rsa.pub  --resource-group-name ${resource_group:?}")
                if [[ $ssh_key_create = *Created* ]]; then
                    echo "$CICD_SSH_KEY created in $region"
                else
                    echo "ssh-key creation failed in $region"
                    exit 1
                fi
            else
                echo "$CICD_SSH_KEY already exists in region $region. So, deleting exist key $CICD_SSH_KEY in region $region"
                ssh_key_delete=$(eval "ibmcloud is key-delete $CICD_SSH_KEY -f")
                if [[ $ssh_key_delete = *deleted* ]]; then
                    echo "Exist $CICD_SSH_KEY deleted in $region"
                    echo "New $CICD_SSH_KEY creating in $region"
                    ssh_key_create=$(eval "ibmcloud is key-create $CICD_SSH_KEY @//artifacts/.ssh/id_rsa.pub  --resource-group-name $resource_group")
                    if [[ $ssh_key_create = *Created* ]]; then
                        echo "New $CICD_SSH_KEY created in $region"
                    else
                        echo "ssh-key creation failed in $region"
                        exit 1
                    fi
                else
                    echo "ssh-key deletion failed in $region"
                fi
            fi
            echo "************SSH-KEY create process in $region done ************"
        else
            echo "Issue Login with IBMCLOUD $auhtenticate"
            exit 1
        fi
    done
}

ssh_key_delete() {
    CHECK_SOLUTION=$1
    SSH_KEY_REGIONS=$2
    LSF_VERSION=$3
    set_ssh_key_name "${CHECK_SOLUTION}" "${SSH_KEY_REGIONS}" "${LSF_VERSION}"
    # Looping all region to create SSH-KEYS
    for region in "${REGIONS[@]}"; do
        disable_update_check=$(eval "ibmcloud config --check-version=false")
        echo "$disable_update_check"
        auhtenticate=$(eval "ibmcloud login --apikey $API_KEY -r $region")
        if [[ $auhtenticate = *OK* ]]; then
            echo "************SSH-KEY deletion process in $region ************"
            ssh_key_delete=$(eval "ibmcloud is key-delete $CICD_SSH_KEY -f")
            if [[ $ssh_key_delete = *deleted* ]]; then
                echo "$CICD_SSH_KEY deleted in $region"
            else
                echo "ssh-key deletion failed in $region"
            fi
            echo "************SSH-KEY delete process in $region done ************"
        else
            echo "Issue Login with IBMCLOUD $auhtenticate"
            exit 1
        fi
    done
}
