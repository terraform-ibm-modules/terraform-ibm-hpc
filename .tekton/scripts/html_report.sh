#!/bin/bash
get_html_report() {
    LOG_FILE=$1
    DIRECTORY=$2
    PR_OR_REGRESSION=$3
    suite=$4
    CHECK_SOLUTION=$5
    BUILD_NUMBER=$6
    pass_var_name=$7
    fail_var_name=$8

    if [[ -z "$7" || -z "$8" ]]; then
        echo "Internal error: pass/fail output variables not provided"
        return 1
    fi

    # nameref to caller variables
    local -n pass_ref=$pass_var_name
    local -n fail_ref=$fail_var_name

    HTML_FILE_NAME="${LOG_FILE%.json}"
    LOG_PATH="${DIRECTORY}/${LOG_FILE}"

    time_stamp=$(date +%d-%m-%Y)

    case "$CHECK_SOLUTION" in
        hpcaas) folder_name="hpcaas/${time_stamp}/${PR_OR_REGRESSION}/${BUILD_NUMBER}" ;;
        lsf) folder_name="lsf/${time_stamp}/${PR_OR_REGRESSION}/${BUILD_NUMBER}" ;;
        lsf-da) folder_name="lsf-da/${time_stamp}/${PR_OR_REGRESSION}/${BUILD_NUMBER}" ;;
        *) folder_name="misc/${time_stamp}/${PR_OR_REGRESSION}/${BUILD_NUMBER}" ;;
    esac

    # Construct HTML report link
    # hpc_custom_reports_repo="https://github.ibm.com/workload-eng-services/hpc-cicd-dashboard.git"
    if [[ "${hpc_custom_reports_repo:?}" != *.git ]]; then
        HTTPS_REPOSITORY="${hpc_custom_reports_repo}.git"
    else
        HTTPS_REPOSITORY="${hpc_custom_reports_repo}"
    fi

    GITHUB_PAGES_REPOSITORY="${HTTPS_REPOSITORY/github.ibm.com/pages.github.ibm.com}"
    GITHUB_PAGES="${GITHUB_PAGES_REPOSITORY%.*}"
    REPORT_URL="${GITHUB_PAGES}/${folder_name}/${HTML_FILE_NAME}.html"
    # REPORT_URL="https://pages.github.ibm.com/workload-eng-services/hpc-cicd-dashboard/lsf-da/06-02-2026/REGRESSION/110/lsf-da-rhel-suite-1.html"

    echo "============================================================"
    echo "Test Summary : ${suite}"
    echo "Build Number : ${BUILD_NUMBER}"
    echo "============================================================"

    if [[ ! -f "$LOG_PATH" ]]; then
        echo "Log file not found: $LOG_PATH"
        pass_ref=0
        fail_ref=0
        return
    fi

    pass_count=0
    fail_count=0

    TEST_NAME_WIDTH=80

    printf "%-${TEST_NAME_WIDTH}s %-8s %-10s\n" "Test Name" "Status" "Time"
    printf "%-${TEST_NAME_WIDTH}s %-8s %-10s\n" \
        "--------------------------------------------------------------------------------" "--------" "----------"

    # PASS tests
    while read -r line; do
        test_name=$(awk '{print $3}' <<< "$line")
        test_time=$(awk -F'[()]' '{print $2}' <<< "$line")
        printf "%-${TEST_NAME_WIDTH}s %-8s %-10s\n" "$test_name" "PASS" "$test_time"
        ((pass_count++))
    done < <(grep "\-\-\- PASS" "$LOG_PATH" || true)

    # FAIL tests
    while read -r line; do
        test_name=$(awk '{print $3}' <<< "$line")
        test_time=$(awk -F'[()]' '{print $2}' <<< "$line")
        printf "%-${TEST_NAME_WIDTH}s %-8s %-10s\n" "$test_name" "FAIL" "$test_time"
        ((fail_count++))
    done < <(grep "\-\-\- FAIL" "$LOG_PATH" || true)


    echo "HTML Report:"
    echo "${suite} : ${REPORT_URL}"
    echo "============================================================"
    for _ in {1..5}; do echo; done

    # return counts via nameref
    # shellcheck disable=SC2034
    pass_ref=$pass_count
    # shellcheck disable=SC2034
    fail_ref=$fail_count

}

common_task_report() {
    suites="$1"              # comma-separated: "suite1,suite2,suite3"
    CHECK_SOLUTION="$2"      # e.g. lsf-da
    CHECK_PR_SUITE="$3"      # PR or REGRESSION

    total_pass=0
    total_fail=0


    DIRECTORY="/artifacts/tests"
    REGRESSION_DIRECTORY="${DIRECTORY}/lsf_tests"

    if [[ "$CHECK_PR_SUITE" == "PR" ]]; then
        WORKING_DIR="$DIRECTORY"
        PR_OR_REGRESSION="PR"
    else
        WORKING_DIR="$REGRESSION_DIRECTORY"
        PR_OR_REGRESSION="REGRESSION"
    fi

    # Convert comma-separated suites → space-separated list
    suites_list="${suites//,/ }"
    for suite in $suites_list; do
        LOG_FILE="${suite}.json"
        LOG_PATH="${WORKING_DIR}/${LOG_FILE}"
        # if [[ ! -f "$LOG_PATH" ]]; then
        #     echo "Log file not found: $LOG_PATH"
        #     continue
        # fi

        suite_pass=0
        suite_fail=0

        get_html_report \
            "${LOG_FILE}" \
            "${WORKING_DIR}" \
            "${PR_OR_REGRESSION}" \
            "${suite}" \
            "${CHECK_SOLUTION}" \
            "${BUILD_NUMBER}" \
            suite_pass \
            suite_fail



        total_pass=$((total_pass + suite_pass))
        total_fail=$((total_fail + suite_fail))

    done

    total_count=$((total_pass + total_fail))

    echo "============================================================"
    echo "Overall Summary"
    echo "------------------------------------------------------------"
    echo "Passed : $total_pass"
    echo "Failed : $total_fail"
    echo "Total  : $total_count"
    echo "============================================================"
}
