#!/bin/bash
cos_upload() {
    CHECK_PR=$1
    export COS_REGION=${cos_region:?}
    export COS_API_KEY_ID=$API_KEY
    export COS_BUCKET=${cos_bucket:?}
    export COS_INSTANCE_CRN=${cos_instance_crn:?}
    CURRENT_DATE="$(date +%d-%m-%Y)"
    COS_FOLDER="TEKTON/$CURRENT_DATE"

    COMMIT_MESSAGE="$(git log -1 --pretty=format:%s)"
    if [[ -z "$COMMIT_MESSAGE" ]]; then
        COMMIT_MESSAGE="manual"
    fi

    if [[ -z "$CHECK_PR" ]]; then
        python3 /artifacts/.tekton/scripts/cos_data.py UPLOAD "$DIRECTORY"/test_output/log* "$COS_FOLDER"/TEST_OUTPUT/"$COMMIT_MESSAGE"/log-"$(date +%d-%m-%Y-%H-%M-%S)"
    fi
    python3 /artifacts/.tekton/scripts/cos_data.py UPLOAD "$LOG_FILE" "$COS_FOLDER"/LOG_DATA/"$COMMIT_MESSAGE"/"$LOG_FILE".log
}
