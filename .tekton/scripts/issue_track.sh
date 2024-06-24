#!/bin/bash
issue_track() {
    LOG_FILE=$1
    CHECK_PR_OR_NEAGTIVE=$2
    CHECK_TASK=$3
    DIRECTORY="/artifacts/tests"
    if [ -d "$DIRECTORY" ]; then
        if [[ "${CHECK_PR_OR_NEAGTIVE}" != "negative_suite" ]]; then
            # Track error/fail from the suites log file
            log_error_check=$(eval "grep -E -w 'FAIL|Error|ERROR' $DIRECTORY/$LOG_FILE")
            if [[ "$log_error_check" ]]; then
                # Skip printing error/fail suites logs on task window
                if [[ "${CHECK_TASK}" != "TASK" ]]; then
                    echo "$log_error_check"
                    echo "Found Error/FAIL/ERROR in plan/apply log. Please check log."
                    exit 1
                else
                    echo "Found Error/FAIL/ERROR in plan/apply log. Please check log."
                    exit 1
                fi
            fi
        fi

        if [[ "${CHECK_PR_OR_NEAGTIVE}" != "PR" ]]; then
            # Track test_output log file initiated or not
            test_output_file_check=$(find $DIRECTORY/test_output/log* 2>/dev/null)
            if [[ -z "$test_output_file_check" ]]; then
                echo "Test output log file not initiated."
                exit 1
            fi
        fi

        # Track suites log file initiated or not
        log_file_check=$(find $DIRECTORY/*.cicd  2>/dev/null)
        if [[ -z "$log_file_check" ]]; then
            echo "Test Suite have not initated and log file not created, check with packages or binaries installation"
            exit 1
        fi
    else
        echo "$DIRECTORY does not exits"
        exit 1
    fi
}

display_test_output() {
    DIRECTORY="/artifacts/tests"
    if [ -d "$DIRECTORY" ]; then
        # Display test_output log file
        test_output_file_check=$(find $DIRECTORY/test_output/log* 2>/dev/null)
        if [[ -z "$test_output_file_check" ]]; then
            echo "Test output log file not initiated."
            exit 1
        else
            echo "********************** Display Test Output Log Start ********************"
            cat $DIRECTORY/test_output/log*
            echo "********************** Display Test Output Log End **********************"
        fi
    else
        echo "$DIRECTORY does not exits"
        exit 1
    fi
}

check_error_test_output() {
    DIRECTORY="/artifacts/tests"
    if [ -d "$DIRECTORY" ]; then
        # Check error in test_output log
        log_error_check=$(eval "grep -E -w 'FAIL|Error|ERROR' ${DIRECTORY/test_output/log*}")
        if [[ "$log_error_check" ]]; then
            echo "********************** Check Error in Test Output Log Start *************"
            echo "$log_error_check"
            echo "********************** Check Error in Test Output Log End **********************"
            echo "Found Error/FAIL/ERROR in the test run output log. Please check log."
        else
            echo "No Error found in ${DIRECTORY/test_output/log*}"
        fi
    else
        echo "$DIRECTORY does not exits"
        exit 1
    fi
}
