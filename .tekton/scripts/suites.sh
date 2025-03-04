#!/bin/bash
common_suite() {
    test_cases="$1"
    suite="$2"
    compute_image_name="$3"
    CHECK_SOLUTION="$4"
    CHECK_PR_SUITE="$5"
    for file in .tekton/scripts/*.sh; do
        # shellcheck source=/dev/null
        source "$file"
    done
    export TF_VAR_ibmcloud_api_key=$API_KEY

    DIRECTORY="/artifacts/tests"
    if [ -d "$DIRECTORY" ]; then
        cd $DIRECTORY || exit
        test_cases="${test_cases//,/|}"
        LOG_FILE=${suite}.json
        VALIDATION_LOG_FILE_NAME=${suite}.log
        export LOG_FILE_NAME=${LOG_FILE}
        echo "**************Validating on ${suite} **************"
        if [[ "$CHECK_PR_SUITE" ]]; then
            if [[ "$CHECK_SOLUTION" == "hpcaas" ]]; then
                # get ssh-key created based on pr-id
                get_pr_ssh_key "${PR_REVISION}" "${CHECK_SOLUTION}"
                SSH_KEY=${CICD_SSH_KEY:?} COMPUTE_IMAGE_NAME=${compute_image_name:?} LOGIN_NODE_IMAGE_NAME=${login_image_name:?} MANAGEMENT_IMAGE_NAME=${management_image_name:?} \
                    ZONE=${zone:?} RESERVATION_ID=${reservation_id:?} CLUSTER_ID=${cluster_id:?} RESOURCE_GROUP=${resource_group:?} \
                    go test -v -timeout 9000m -run "${test_cases}" | tee -a "$LOG_FILE"
                # Upload log/test_output files to cos bucket
                cos_upload "PR" "${CHECK_SOLUTION}" "${DIRECTORY}"

                # push custom reports to custom-reports repository
                push_reports "${LOG_FILE}" "${DIRECTORY}" "PR" "${suite}" "${CHECK_SOLUTION}"

                # Checking any error/issue from log file for pr
                issue_track "${LOG_FILE}" "PR"
            fi

            if [[ "$CHECK_SOLUTION" == "lsf" ]]; then
                # get ssh-key created based on pr-id
                get_pr_ssh_key "${PR_REVISION}" "${CHECK_SOLUTION}"
                SSH_KEY=${CICD_SSH_KEY:?} COMPUTE_IMAGE_NAME=${compute_image_name:?} LOGIN_NODE_IMAGE_NAME=${login_image_name:?} MANAGEMENT_IMAGE_NAME=${management_image_name:?} \
                    ZONE=${zone:?} SOLUTION=${solution:?} IBM_CUSTOMER_NUMBER=${ibm_customer_number:?} RESOURCE_GROUP=${resource_group:?} \
                    go test -v -timeout 9000m -run "${test_cases}" | tee -a "$LOG_FILE"
                # Upload log/test_output files to cos bucket
                cos_upload "PR" "${CHECK_SOLUTION}" "${DIRECTORY}"

                # push custom reports to custom-reports repository
                push_reports "${LOG_FILE}" "${DIRECTORY}" "PR" "${suite}" "${CHECK_SOLUTION}"

                # Checking any error/issue from log file for pr
                issue_track "${LOG_FILE}" "PR"
            fi

        else
            if [[ "$CHECK_SOLUTION" == "hpcaas" ]]; then
                # get ssh-key created based on commit-id
                get_commit_ssh_key "${REVISION}" "${CHECK_SOLUTION}"
                SSH_KEY=${CICD_SSH_KEY:?} US_EAST_ZONE=${us_east_zone:?} US_EAST_CLUSTER_ID=${us_east_cluster_id:?} \
                    US_EAST_RESERVATION_ID=${us_east_reservation_id:?} US_SOUTH_ZONE=${us_south_zone:?} \
                    US_SOUTH_CLUSTER_ID=${us_south_cluster_id:?} US_SOUTH_RESERVATION_ID=${us_south_reservation_id:?} \
                    EU_DE_ZONE=${eu_de_zone:?} EU_DE_CLUSTER_ID=${eu_de_cluster_id:?} EU_DE_RESERVATION_ID=${eu_de_reservation_id:?} \
                    EU_DE_RESERVATION_ID=${eu_de_reservation_id:?} COMPUTE_IMAGE_NAME=${compute_image_name:?} \
                    LOGIN_NODE_IMAGE_NAME=${login_image_name:?} ZONE=${zone:?} RESERVATION_ID=${reservation_id:?} \
                    CLUSTER_ID=${cluster_id:?} RESOURCE_GROUP=${resource_group:?} MANAGEMENT_IMAGE_NAME=${management_image_name:?} \
                    go test -v -timeout 9000m -run "${test_cases}" | tee -a "$LOG_FILE"
                # Upload log/test_output files to cos bucket
                cos_upload "REGRESSION" "${CHECK_SOLUTION}" "${DIRECTORY}" "${VALIDATION_LOG_FILE_NAME}"

                # push custom reports to custom-reports repository
                push_reports "${LOG_FILE}" "${DIRECTORY}" "REGRESSION" "${suite}" "${CHECK_SOLUTION}"

                # Checking any error/issue from log file for commit/push
                issue_track "${LOG_FILE}"
            fi

            if [[ "$CHECK_SOLUTION" == "lsf" ]]; then
                # get ssh-key created based on commit-id
                get_commit_ssh_key "${REVISION}" "${CHECK_SOLUTION}"
                SSH_KEY=${CICD_SSH_KEY:?} COMPUTE_IMAGE_NAME=${compute_image_name:?} LOGIN_NODE_IMAGE_NAME=${login_image_name:?} MANAGEMENT_IMAGE_NAME=${management_image_name:?} \
                    ZONE=${zone:?} SOLUTION=${solution:?} IBM_CUSTOMER_NUMBER=${ibm_customer_number:?} RESOURCE_GROUP=${resource_group:?} \
                    go test -v -timeout 9000m -run "${test_cases}" | tee -a "$LOG_FILE"
                # Upload log/test_output files to cos bucket
                cos_upload "REGRESSION" "${CHECK_SOLUTION}" "${DIRECTORY}" "${VALIDATION_LOG_FILE_NAME}"

                # push custom reports to custom-reports repository
                push_reports "${LOG_FILE}" "${DIRECTORY}" "REGRESSION" "${suite}" "${CHECK_SOLUTION}"

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

######################## HPCaaS Testcases Start ########################
# pr based suite on rhel
hpcaas_pr_rhel_suite() {
    suite=hpcaas-pr-rhel-suite
    solution=hpcaas
    test_cases="TestRunDefault"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}" "PR"
}

# pr based suite on ubuntu
hpcaas_pr_ubuntu_suite() {
    suite=hpcaas-pr-ubuntu-suite
    solution=hpcaas
    test_cases="TestRunDefault"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_ubuntu:?}" "${solution:?}" "PR"
}

# commit based suite on rhel-suite-1
hpcaas_rhel_suite_1() {
    suite=hpcaas-rhel-suite-1
    solution=hpcaas
    test_cases="TestRunBasic,TestRunAppCenter,TestRunNoKMSAndHTOff,TestRunCosAndVpcFlowLogs"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}"
}

# commit based suite on rhel-suite-2
hpcaas_rhel_suite_2() {
    suite=hpcaas-rhel-suite-2
    solution=hpcaas
    test_cases="TestRunLDAP,TestRunLDAPAndPac,TestRunCustomRGAsNonDefault,TestRunUsingExistingKMSInstanceIDAndWithoutKey"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}"
}

# commit based suite on rhel-suite-3
hpcaas_rhel_suite_3() {
    suite=hpcaas-rhel-suite-3
    solution=hpcaas
    test_cases="TestRunCreateVpc"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}"
}

# commit based suite on ubuntu-suite-1
hpcaas_ubuntu_suite_1() {
    suite=hpcaas-ubuntu-suite-1
    solution=hpcaas
    test_cases="TestRunVpcWithCustomDns"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_ubuntu:?}" "${solution:?}"
}

# commit based suite on ubuntu-suite-2
hpcaas_ubuntu_suite_2() {
    suite=hpcaas-ubuntu-suite-2
    solution=hpcaas
    test_cases="TestRunUsingExistingKMS,TestRunLDAPAndPac,TestRunCustomRGAsNull"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_ubuntu:?}" "${solution:?}"
}

# commit based suite on ubuntu-suite-3
hpcaas_ubuntu_suite_3() {
    suite=hpcaas-ubuntu-suite-3
    solution=hpcaas
    test_cases="TestRunBasic,TestRunNoKMSAndHTOff,TestRunExistingLDAP"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_ubuntu:?}" "${solution:?}"
}

# regions based suite on regions-suite
hpcaas_regions_suite() {
    suite=hpcaas-regions-suite
    solution=hpcaas
    test_cases="TestRunInUsEastRegion,TestRunInEuDeRegion,TestRunInUSSouthRegion,TestRunCIDRsAsNonDefault,TestRunObservability"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}"
}

# negative based suite on negative-suite
hpcaas_negative_suite() {
    suite=hpcaas-negative-suite
    solution=hpcaas
    test_cases="TestRunHPCWithoutMandatory,TestRunHPCInvalidReservationID,TestRunInvalidLDAPServerIP,TestRunInvalidLDAPUsernamePassword,TestRunInvalidAPPCenterPassword,TestRunInvalidDomainName,TestRunKMSInstanceNameAndKMSKeyNameWithInvalidValue,TestRunExistSubnetIDVpcNameAsNull,TestRunInvalidSshKeysAndRemoteAllowedIP,TestRunHPCInvalidReservationIDAndContractID"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}"
}

######################## HPCaaS Testcases End ########################

######################## LSF Testcases Start ########################
# pr based suite on rhel
lsf_pr_rhel_suite() {
    suite=lsf-pr-rhel-suite
    solution=lsf
    test_cases="TestRunDefault"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}" "PR"
}

# # pr based suite on ubuntu
# lsf_pr_ubuntu_suite() {
#     suite=lsf-pr-ubuntu
#     solution=lsf
#     test_cases="TestRunDefault"
#     new_line="${test_cases//,/$'\n'}"
#     echo "************** Going to run ${suite} ${new_line} **************"
#     common_suite "${test_cases}" "${suite}" "${compute_image_name_ubuntu:?}" "${solution:?}" "PR"
# }

# commit based suite on rhel-suite-1
lsf_rhel_suite_1() {
    suite=lsf-rhel-suite-1
    solution=lsf
    test_cases="TestRunBasic,TestRunAppCenter,TestRunNoKMSAndHTOff"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}"
}

# commit based suite on lsf-rhel-suite-2
lsf_rhel_suite_2() {
    suite=lsf-rhel-suite-2
    solution=lsf
    test_cases="TestRunCreateVpc"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}"
}

# commit based suite on lsf-rhel-suite-3
lsf_rhel_suite_3() {
    suite=lsf-rhel-suite-3
    solution=lsf
    test_cases="TestRunCustomRGAsNull,TestRunExistingLDAP,TestRunSCCEnabled"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}"
}

# commit based suite on lsf-rhel-suite-4
lsf_rhel_suite_4() {
    suite=lsf-rhel-suite-4
    solution=lsf
    test_cases="TestRunLDAP,TestRunLDAPAndPac,TestRunDedicatedHost"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}"
}

# commit based suite on lsf-rhel-suite-5
lsf_rhel_suite_5() {
    suite=lsf-rhel-suite-5
    solution=lsf
    test_cases="TestRunCosAndVpcFlowLogs,TestRunLSFClusterCreationWithZeroWorkerNodes"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}"
}

# commit based suite on lsf-rhel-suite-6
lsf_rhel_suite_6() {
    suite=lsf-rhel-suite-6
    solution=lsf
    test_cases="TestRunVpcWithCustomDns"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}"
}

# commit based suite on lsf-rhel-suite-7
lsf_rhel_suite_7() {
    suite=lsf-rhel-suite-7
    solution=lsf
    test_cases="TestRunCIDRsAsNonDefault,TestRunObservability"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}"
}

# commit based suite on lsf-rhel-suite-8
lsf_rhel_suite_8() {
    suite=lsf-rhel-suite-8
    solution=lsf
    test_cases="TestRunUsingExistingKMSInstanceIDAndWithoutKey,TestRunCustomRGAsNonDefault"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}"
}
# # commit based suite on ubuntu-suite-1
# lsf_ubuntu_suite_1() {
#     suite=lsf-ubuntu-suite-1
#     solution=lsf
#     test_cases="TestRunVpcWithCustomDns"
#     new_line="${test_cases//,/$'\n'}"
#     echo "************** Going to run ${suite} ${new_line} **************"
#     common_suite "${test_cases}" "${suite}" "${compute_image_name_ubuntu:?}" "${solution:?}"
# }

# # commit based suite on ubuntu-suite-2
# lsf_ubuntu_suite_2() {
#     suite=lsf-ubuntu-suite-2
#     solution=lsf
#     test_cases="TestRunUsingExistingKMS,TestRunLDAPAndPac,TestRunCustomRGAsNull"
#     new_line="${test_cases//,/$'\n'}"
#     echo "************** Going to run ${suite} ${new_line} **************"
#     common_suite "${test_cases}" "${suite}" "${compute_image_name_ubuntu:?}" "${solution:?}"
# }

# # commit based suite on ubuntu-suite-3
# lsf_ubuntu_suite_3() {
#     suite=lsf-ubuntu-suite-3
#     solution=lsf
#     test_cases="TestRunBasic,TestRunNoKMSAndHTOff,TestRunExistingLDAP"
#     new_line="${test_cases//,/$'\n'}"
#     echo "************** Going to run ${suite} ${new_line} **************"
#     common_suite "${test_cases}" "${suite}" "${compute_image_name_ubuntu:?}" "${solution:?}"
# }

# regions based suite on regions-suite
lsf_regions_suite() {
    suite=lsf-regions-suite
    solution=lsf
    # test_cases="TestRunInUSSouthRegion"
    test_cases="TestRunInUsEastRegion,TestRunInEuDeRegion,TestRunInJPTokyoRegion"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}"
}

# negative based suite on negative-suite
lsf_negative_suite_1() {
    suite=lsf-negative-suite-1
    solution=lsf
    test_cases="TestRunLSFInvalidIBMCustomerNumber,TestRunInvalidLDAPServerIP,TestRunInvalidDomainName,TestRunInvalidDedicatedHostProfile"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}"
}

# negative based suite on negative-suite
lsf_negative_suite_2() {
    suite=lsf-negative-suite-2
    solution=lsf
    test_cases="TestRunKMSInstanceNameAndKMSKeyNameWithInvalidValue,TestRunExistSubnetIDVpcNameAsNull,TestRunInvalidSshKeysAndRemoteAllowedIP,TestRunInvalidDedicatedHostConfigurationWithZeroWorkerNodes"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}"
}

# negative based suite on negative-suite
lsf_negative_suite_3() {
    suite=lsf-negative-suite-3
    solution=lsf
    test_cases="TestRunInvalidLDAPUsernamePassword,TestRunInvalidAPPCenterPassword,TestRunLSFWithoutMandatory,TestRunInvalidMinWorkerNodeCountGreaterThanMax"
    new_line="${test_cases//,/$'\n'}"
    echo "************** Going to run ${suite} ${new_line} **************"
    common_suite "${test_cases}" "${suite}" "${compute_image_name_rhel:?}" "${solution:?}"
}

######################## HPCaaS Testcases End ########################
