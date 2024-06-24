#!/bin/bash
common_suite() {
    test_cases="$1"
    suite="$2"
    compute_image_name="$3"
    CHECK_PR_SUITE="$4"
    for file in .tekton/scripts/*.sh
        do
        # shellcheck source=/dev/null
        source "$file"
    done
        export TF_VAR_ibmcloud_api_key=$API_KEY
        DIRECTORY="/artifacts/tests"
        if [ -d "$DIRECTORY" ]; then
        cd $DIRECTORY || exit
            test_cases="${test_cases//,/|}"
            LOG_FILE=pipeline-${suite}-$(date +%d-%m-%Y-%H-%M-%S).cicd
            export LOG_FILE
            echo "**************Validating on ${suite} **************"
            if [[ "$CHECK_PR_SUITE" ]]; then
                # get ssh-key created based on pr-id
                get_pr_ssh_key "${PR_REVISION}"
                SSH_KEY=${CICD_SSH_KEY:?} COMPUTE_IMAGE_NAME=${compute_image_name:?} LOGIN_NODE_IMAGE_NAME=${login_image_name:?} \
                ZONE=${zone:?}  RESERVATION_ID=${reservation_id:?} CLUSTER_ID=${cluster_id:?} RESOURCE_GROUP=${resource_group:?} \
                go test -v -timeout 9000m -run "${test_cases}" | tee -a "$LOG_FILE"
                # Upload log/test_output files to cos bucket
                cos_upload "PR"
                # Checking any error/issue from log file for pr
                issue_track "${LOG_FILE}" "PR" "TASK"

            else
                # get ssh-key created based on commit-id
                get_commit_ssh_key "${REVISION}"
                SSH_KEY=${CICD_SSH_KEY:?} US_EAST_ZONE=${us_east_zone:?} US_EAST_CLUSTER_ID=${us_east_cluster_id:?} \
                US_EAST_RESERVATION_ID=${us_east_reservation_id:?} US_SOUTH_ZONE=${us_south_zone:?} \
                US_SOUTH_CLUSTER_ID=${us_south_cluster_id:?} US_SOUTH_RESERVATION_ID=${us_south_reservation_id:?} \
                EU_DE_ZONE=${eu_de_zone:?} EU_DE_CLUSTER_ID=${eu_de_cluster_id:?} EU_DE_RESERVATION_ID=${eu_de_reservation_id:?} \
                EU_DE_RESERVATION_ID=${eu_de_reservation_id:?} COMPUTE_IMAGE_NAME=${compute_image_name:?} \
                LOGIN_NODE_IMAGE_NAME=${login_image_name:?} ZONE=${zone:?} RESERVATION_ID=${reservation_id:?} \
                CLUSTER_ID=${cluster_id:?} RESOURCE_GROUP=${resource_group:?} \
                go test -v -timeout 9000m -run "${test_cases}" | tee -a "$LOG_FILE"
                # Upload log/test_output files to cos bucket
                cos_upload

                if [[ "${suite}" == "negative_suite" ]]; then
                    # Skipping error/issue track from log file for commit/push to negative testcases
                    issue_track "${LOG_FILE}" "negative_suite" "TASK"
                else
                    # Checking any error/issue from log file for commit/push
                    issue_track "${LOG_FILE}"
                fi
            fi
        else
        pwd
        ls -a
        echo "$DIRECTORY does not exists"
        exit 1
        fi
}

# pr based suite on rhel
pr_rhel_suite() {
    suite=pr-rhel
    test_cases="TestRunDefault"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "PR"
}

# pr based suite on ubuntu
pr_ubuntu_suite() {
    suite=pr-ubuntu
    test_cases="TestRunDefault"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_ubuntu:?}" "PR"
}

# commit based suite on rhel-suite-1
rhel_suite_1() {
    suite=rhel-suite-1
    test_cases="TestRunBasic,TestRunAppCenter,TestRunNoKMSAndHTOff"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}"
}

# commit based suite on rhel-suite-2
rhel_suite_2() {
    suite=rhel-suite-2
    test_cases="TestRunLDAP,TestRunLDAPAndPac,TestRunCustomRGAsNonDefault"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}"
}

# commit based suite on rhel-suite-3
rhel_suite_3() {
    suite=rhel-suite-3
    test_cases="TestRunCreateVpc"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}"
}

# commit based suite on ubuntu-suite-1
ubuntu_suite_1() {
    suite=ubuntu-suite-1
    test_cases="TestRunVpcWithCustomDns"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_ubuntu:?}"
}

# commit based suite on ubuntu-suite-2
ubuntu_suite_2() {
    suite=ubuntu-suite-2
    test_cases="TestRunUsingExistingKMS,TestRunLDAPAndPac,TestRunCustomRGAsNull"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_ubuntu:?}"
}

# commit based suite on ubuntu-suite-3
ubuntu_suite_3() {
    suite=ubuntu-suite-3
    test_cases="TestRunBasic,TestRunNoKMSAndHTOff"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_ubuntu:?}"
}

# regions based suite on regions-suite
regions_suite() {
    suite=regions-suite
    test_cases="TestRunInUsEastRegion,TestRunInEuDeRegion,TestRunInUSSouthRegion,TestRunCIDRsAsNonDefault,TestRunExistingPACEnvironment"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}"
}

# negative based suite on negative-suite
negative_suite() {
    suite=negative-suite
    test_cases="TestRunWithoutMandatory,TestRunInvalidReservationIDAndContractID,TestRunInvalidLDAPServerIP,TestRunInvalidLDAPUsernamePassword,TestRunInvalidAPPCenterPassword,TestRunInvalidDomainName,TestRunKMSInstanceNameAndKMSKeyNameWithInvalidValue,TestRunExistSubnetIDVpcNameAsNull"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}"
}
