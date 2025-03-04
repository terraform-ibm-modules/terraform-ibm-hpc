#!/bin/bash
cos_upload() {
    CHECK_PR=$1
    CHECK_SOLUTION=$2
    DIRECTORY=$3
    VALIDATION_LOG_FILE_NAME=$4
    CURRENT_DATE_FILE=$(date +%d-%m-%Y-%H-%M-%S)
    VALIDATION_LOG_FILE=$(echo "$VALIDATION_LOG_FILE_NAME" | cut -f 1 -d '.')-${CURRENT_DATE_FILE}.log
    export COS_REGION=${cos_region:?}
    export COS_API_KEY_ID=${cos_api_key:?} # pragma: allowlist secret
    export COS_BUCKET=${cos_bucket:?}
    export COS_INSTANCE_CRN=${cos_instance_crn:?}
    CURRENT_DATE="$(date +%d-%m-%Y)"
    COS_FOLDER="TEKTON/$CURRENT_DATE"

    COMMIT_MESSAGE="$(git log -1 --pretty=format:%s)"
    if [[ -z "$COMMIT_MESSAGE" ]]; then
        COMMIT_MESSAGE="manual"
    fi

    ls -ltr "$DIRECTORY"/logs

    echo "***********INSTALL IBM-COS-SDK *************"
    python3 -m pip install --pre --upgrade ibm-cos-sdk==2.0.1 --quiet
    echo "***********INSTALLED IBM-COS-SDK *************"

    if [[ "$CHECK_SOLUTION" == "hpcaas" ]]; then
        if [[ "$CHECK_PR" == "REGRESSION" ]]; then
            python3 /artifacts/.tekton/scripts/cos_data.py UPLOAD "$DIRECTORY"/logs/"$VALIDATION_LOG_FILE_NAME" "$COS_FOLDER"/HPCAAS/VALIDATION_LOG/"$COMMIT_MESSAGE"/"$VALIDATION_LOG_FILE"
        fi
        python3 /artifacts/.tekton/scripts/cos_data.py UPLOAD "$LOG_FILE_NAME" "$COS_FOLDER"/HPCAAS/INFRA_LOG/"$COMMIT_MESSAGE"/"$LOG_FILE_NAME"-"$CURRENT_DATE_FILE".log
    fi
    if [[ "$CHECK_SOLUTION" == "lsf" ]]; then
        if [[ "$CHECK_PR" == "REGRESSION" ]]; then
            python3 /artifacts/.tekton/scripts/cos_data.py UPLOAD "$DIRECTORY"/logs/"$VALIDATION_LOG_FILE_NAME" "$COS_FOLDER"/LSF/VALIDATION_LOG/"$COMMIT_MESSAGE"/"$VALIDATION_LOG_FILE"
        fi
        python3 /artifacts/.tekton/scripts/cos_data.py UPLOAD "$LOG_FILE_NAME" "$COS_FOLDER"/LSF/INFRA_LOG/"$COMMIT_MESSAGE"/"$LOG_FILE_NAME"-"$CURRENT_DATE_FILE".log
    fi
}
