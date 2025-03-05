#!/bin/bash

push_reports() {
    LOG_FILE=$1
    DIRECTORY=$2
    PR_OR_REGRESSION=$3
    suite=$4
    CHECK_SOLUTION=$5
    BUILD_NUMBER=$6
    HTML_FILE_NAME=$(echo "$LOG_FILE" | cut -d'.' -f1)
    mkdir -p "$DIRECTORY"/push_reports
    cd "$DIRECTORY"/push_reports || exit
    # COMMIT_ID="$(git log --format="%H" -n 1)"
    time_stamp=$(date +%d-%m-%Y)
    if [[ "${hpc_custom_reports_repo:?}" != *.git ]]; then
        echo "Adding .git suffix to Repository URL"
        HTTPS_REPOSITORY="${hpc_custom_reports_repo:?}.git"
    else
        HTTPS_REPOSITORY="${hpc_custom_reports_repo:?}"
    fi
    REPOSITORY_CLONE="${HTTPS_REPOSITORY/github.ibm.com/${git_user_name:?}:${git_access_token:?}@github.ibm.com}"
    echo "Cloning repository : ${REPOSITORY_CLONE}"
    git clone -b "${hpc_custom_reports_branch:?}" "${REPOSITORY_CLONE}" "${suite}"
    cd "${suite}" || exit
    if [[ "$CHECK_SOLUTION" == "hpcaas" ]]; then
        folder_name="hpcaas/${time_stamp}/$PR_OR_REGRESSION/${BUILD_NUMBER}"
    fi
    if [[ "$CHECK_SOLUTION" == "lsf" ]]; then
        folder_name="lsf/${time_stamp}/$PR_OR_REGRESSION/${BUILD_NUMBER}"
    fi
    mkdir -p "${folder_name}"
    git pull origin "${hpc_custom_reports_branch:?}"
    cp "$DIRECTORY"/"${HTML_FILE_NAME}".html "$DIRECTORY"/push_reports/"${suite}"/"${folder_name}"
    git config --global user.name "${git_user_name:?}"
    git config --global user.email "${git_user_email:?}"
    git add .
    git commit -m "tekton-build-number-$BUILD_NUMBER"
    git push origin "${hpc_custom_reports_branch:?}" -f
    echo "********************* GitHub Pages Link ************************"
    echo "Please click the below link to see the ${suite} results"
    GITHUB_PAGES_REPOSITORY="${HTTPS_REPOSITORY/github.ibm.com/pages.github.ibm.com}"
    GITHUB_PAGES="${GITHUB_PAGES_REPOSITORY%.*}"
    echo "${suite} : ${GITHUB_PAGES}/$folder_name/${HTML_FILE_NAME}.html"
    echo "********************* GitHub Pages Link ************************"
}
