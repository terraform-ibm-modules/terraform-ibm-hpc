#!/bin/bash
error_check_on_all_file() {
    DIRECTORY=$1
    pattern=$2
    infra_or_validation=$3
    results=()
    for file in "$DIRECTORY"/$pattern; do
        if [ -f "$file" ]; then
            if [[ "${file}" == *"negative"* ]]; then
                infra_validation_negative_log_fail_check=$(eval "grep -v 'Terraform upgrade output:' $file" | grep -E -w 'FAIL')
                if [[ "$infra_validation_negative_log_fail_check" ]]; then
                    results+=("true")
                    if [[ "${infra_or_validation}" == "infra" ]]; then
                        echo "FAIL found in the ${infra_or_validation} log file  : $file"
                    elif [[ "${infra_or_validation}" == "validation" ]]; then
                        echo "FAIL found in the ${infra_or_validation} log file  : $file"
                    fi
                fi
            else
                infra_validation_log_error_check=$(eval "grep -v 'Terraform upgrade output:' $file" | grep -E -w 'FAIL|Error|ERROR')
                if [[ "$infra_validation_log_error_check" ]]; then
                    results+=("true")
                    if [[ "${infra_or_validation}" == "infra" ]]; then
                        echo "ERROR found in the ${infra_or_validation} log file : $file"
                    elif [[ "${infra_or_validation}" == "validation" ]]; then
                        echo "ERROR found in the ${infra_or_validation} log file : $file"
                    fi
                fi
            fi
        else
            echo "No file found with ${pattern} the extension"
            exit 1
        fi
    done
    # Check the log has ERROR/FAIL by checking length of the array with true
    arraylength=${#results[@]}
    if [[ "$arraylength" != 0 ]]; then
        exit 1
    fi
}

issue_track() {
    LOG_FILE_NAME=$1
    CHECK_PR_OR_TASK=$2
    DIRECTORY="/artifacts/tests"
    if [ -d "$DIRECTORY" ]; then
        if [[ "${LOG_FILE_NAME}" == *"negative"* ]]; then
            negative_log_error_check=$(eval "grep -v 'Terraform upgrade output:' $DIRECTORY/$LOG_FILE_NAME" | grep 'FAIL')
            if [[ "$negative_log_error_check" ]]; then
                echo "${negative_log_error_check}"
                echo "Found FAIL in plan/apply log. Please check log : ${LOG_FILE_NAME}"
                exit 1
            fi
        else
            # Track error/fail from the suites log file
            log_error_check=$(eval "grep -v 'Terraform upgrade output:' $DIRECTORY/$LOG_FILE_NAME" | grep -E -w 'FAIL|Error|ERROR')
            if [[ "$log_error_check" ]]; then
                echo "${log_error_check}"
                echo "Found Error/FAIL/ERROR in plan/apply log. Please check log : ${LOG_FILE_NAME}"
                exit 1
            fi
        fi

        if [[ "${CHECK_PR_OR_TASK}" != "PR" ]]; then
            VALIDATION_LOG_FILE=$(echo "$LOG_FILE_NAME" | cut -f 1 -d '.').log
            # Track test_output log file initiated or not
            test_output_file_check=$(find $DIRECTORY/logs/"$VALIDATION_LOG_FILE" 2>/dev/null)
            if [[ -z "$test_output_file_check" ]]; then
                echo "Validation log file not initiated under ${DIRECTORY/logs/}"
                exit 1
            fi
        fi

        # Track suites log file initiated or not
        log_file_check=$(find $DIRECTORY/*.json 2>/dev/null)
        if [[ -z "$log_file_check" ]]; then
            echo "Infra log not initiated under ${DIRECTORY}"
            exit 1
        fi
    else
        echo "$DIRECTORY does not exits"
        exit 1
    fi
}

display_validation_log() {
    LOG_FILE_NAME=$1
    DIRECTORY="/artifacts/tests"
    if [ -d "$DIRECTORY" ]; then
        # Display test_output log file
        validation_log_file_check=$(find $DIRECTORY/logs/"$LOG_FILE_NAME" 2>/dev/null)
        if [[ -z "$validation_log_file_check" ]]; then
            echo "Test output log file not initiated."
            exit 1
        else
            echo "********************** DISPLAY ${LOG_FILE_NAME} VALIDATION OUTPUT LOG ********************"
            cat $DIRECTORY/logs/"$LOG_FILE_NAME"
            echo "********************** DISPLAY ${LOG_FILE_NAME} VALIDATION OUTPUT LOG **********************"

            echo "##################################################################################"
            echo "##################################################################################"
            echo "################################# DISPLAY ERROR ##################################"
            echo "##################################################################################"
            echo "##################################################################################"
            if [[ "${LOG_FILE_NAME}" == *"negative"* ]]; then
                validation_log_error_check=$(eval "grep -v 'Terraform upgrade output:' $DIRECTORY/logs/$LOG_FILE_NAME" | grep -E -w 'FAIL')
            else
                validation_log_error_check=$(eval "grep -v 'Terraform upgrade output:' $DIRECTORY/logs/$LOG_FILE_NAME" | grep -E -w 'FAIL|Error|ERROR')
            fi

            # Display if any error in validation log
            if [[ "$validation_log_error_check" ]]; then
                echo "********************** ERROR CHECK in  ${LOG_FILE_NAME} VALIDATION OUTPUT LOG **********************"
                echo "$validation_log_error_check"
                echo "********************** ERROR CHECK in  ${LOG_FILE_NAME} VALIDATION OUTPUT LOG **********************"
                exit 1
            else
                echo "No Error found in $DIRECTORY/logs/$LOG_FILE_NAME"
            fi
        fi
    else
        echo "$DIRECTORY does not exits"
        exit 1
    fi
}
