#!/bin/bash
#
# Licensed Materials - Property of IBM
# 5725-S00 (C) Copyright IBM Corp. 2024. All Rights Reserved.
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
SCRIPT_FOLDER=$(realpath "$(dirname "$0")")
PROJECT_FOLDER=$(realpath "$SCRIPT_FOLDER/..")

IAM_ENDPOINT_URL="https://iam.cloud.ibm.com/identity/token"
RESOURCE_CONTROLLER_ENDPOINT_URL="https://resource-controller.cloud.ibm.com"
CODE_ENGINE_API_ENDPOINT_URL="https://api.REGION.codeengine.cloud.ibm.com"
HPC_API_ENDPOINT_URL="https://hpc-api.REGION.codeengine.cloud.ibm.com"
V2_CONTEXT_ROOT="v2"
V3_CONTEXT_ROOT="v3"
V2BETA_CONTEXT_ROOT="v2beta"

TMP_DIR="/tmp"
HTTP_OUTPUT_FILE="${TMP_DIR}/hpcaas_http_output.log"
CODE_ENGINE_PROJECT_GUID_FILE="${PROJECT_FOLDER}/assets/hpcaas-ce-project-guid.cfg"

RESERVATION_ID=""
REGION=""
RESOURCE_GROUP_ID=""

LOG_FILE="/dev/stdout"

# Script return code:
# 0 - Success, a Reservation for the input RESERVATION_ID exists and a Code Engine Project exists for it.
# 1 - IBM_CLOUD_API_KEY environment variable not provided.
# 2 - Parsing error, the script was not invoked correctly.
# 3 - Cannot retrieve JWT token, the script cannot exchange the IBM Cloud API key with a JWT token.
# 4 - Cannot retrieve a GUID for the input Reservation ID.
# 5 - Reservation doesn't exist, a Reservation for the input RESERVATION_ID doesn't.
# 6 - Cannot create the Code Engine project.
# 7 - Code Engine project creation timeout expired.
# 8 - Cannot associate the Code Engine project with guid GUID to the Reservation with id RESERVATION_ID.

####################################################################################################
# log
#
# Description:
#     this function print the input message on a log file.
# Input:
#     message, the message to print
# Output:
#     message, the message with variable and timestamp rendered.
####################################################################################################
log() {
    local message=$1

    # Create the timestamp to add in the log message
    timestamp=$(date +'%Y%m%d %H:%M:%S')
    # Print the message in the log file
    echo "[$timestamp] ${message}" >> "${LOG_FILE}"
}

####################################################################################################
# usage
#
# Description:
#     this function prints the usage and exit with an error
####################################################################################################
usage() {
    log "Usage: $0 [options]"
    log "Options:"
    log "  --reservation-id    id  | -r id : Specify the Reservation ID"
    log "  --region            id  | -e id : Specify the Region"
    log "  --resource-group-id id  | -e id : Specify the Resource Group ID"
    log "  [--output <file>]       | -o [--output <file>] : Specify the log file. Default is stdout."
    exit 2
}

####################################################################################################
# parse_args
#
# Description:
#     this function parse the input parameters. The following parameters are supported:
#     --reservation-id    id  | -r id
#     --region            id  | -e id
#     --resource-group-id id  | -e id : Specify the Resource Group ID
#    [--output <file>]        | -o [--output <file>] : Specify the log file. Default is stdout
# Input:
#     input parameters, the input parameters to parse
# Output:
#     usage, the usage is printed if an error occured
####################################################################################################
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --reservation-id|-r)
                shift
                RESERVATION_ID="$1";;
            --region|-e)
                shift
                REGION="$1";;
            --resource-group-id|-s)
                shift
                RESOURCE_GROUP_ID="$1";;
            --output|-o)
                shift
                LOG_FILE="$1";;
            *)
                log "ERROR: parsing of the input arguments failed."
                log "ERROR Details: invalid option $1."
                usage;;
        esac
        shift
    done
    # Verify if the required options have been provided
    if [[ -z "${RESERVATION_ID}" || -z "${REGION}" || -z "${RESOURCE_GROUP_ID}" ]]; then
        log "ERROR: parsing of the input arguments failed."
        log "ERROR Details: the options --reservation-id, --region, and --resource-group-id are required."
        usage
    fi

    # Array contenente i valori consentiti per la regione
    local allowed_regions=("us-east" "us-south" "eu-de")

    # Verifica se la regione specificata è tra i valori consentiti
    # shellcheck disable=SC2199,SC2076
    if [[ ! " ${allowed_regions[@]} " =~ " ${REGION} " ]]; then
        log "ERROR: parsing of the input arguments failed."
        log "ERROR Details: Invalid region specified. Region must be one of: ${allowed_regions[*]}."
        usage
    fi
}

####################################################################################################
# get_token
#
# Description:
#     this function validates the IBM Cloud API Key and return a JWT Baerer token to use for authentication
#     when Code Engine API are invoked. This function takes in input the IBM Cloud API Key and return the
#     JWT token.
# Input:
#     api_key, the IBM Cloud API key that identify the IBM Cloud User account.
# Output:
#     token, the JWT token if the function is successful
#     http status, in case of failure the HTTP status is printed
#     error message, in case of failure the error message is printed
# Return:
#     0, success
#     1, failure
####################################################################################################
get_token() {
    local api_key="$1"
    local response
    local http_status
    local json_response
    local token
    local error_message

    # The IBM tool https://github.com/ibm/detect-secrets detected the secret we passed to the API.
    # However, this is aa public secret so no real exposure exists.

    # This is the curl used to retrieve the JWT token given the IBM Cloud API Key in input
    response=$(curl -s -w "%{http_code}" --request POST --url ${IAM_ENDPOINT_URL} --header 'Authorization: Basic Yng6Yng=' --header 'Content-Type: application/x-www-form-urlencoded' --data grant_type=urn:ibm:params:oauth:grant-type:apikey --data apikey="${api_key}") # pragma: allowlist secret

    # The curl return a reply with the following format { ... JSON ... }HTTPSTATUS.
    # These two lines separate the HTTP STATUS from the JSON reply.
    http_status="${response: -3}"
    json_response=${response%???}

    # If HTTP Status = 200 the JWT token is printed and 0 is returned, otherwise
    # 1 is printed (meaning error) and HTTP STATUS and error messages are printed.
    # The reason for this is that if something goes wrong, the caller can print the HTTP STATUS
    # code and the error messages so that the customer can understand the problem.
    if [ "$http_status" -eq 200 ]; then
        token=$(echo "$json_response" | jq -r '.access_token')
        echo "$token"
        return 0
    else
        error_message=$(echo "$json_response" | jq -r '.errorMessage')
        echo "$http_status"
        echo "$error_message"
        return 1
    fi
}

####################################################################################################
# get_guid_from_reservation_id
#
# Description:
#     this function check if a Code Engine Project exists for the input reservation_id. If so,
#     the function return with success, otherwise an error is returned.
# Input:
#     jwt_token, the jwt token
#     reservation_id, the reservation id to check
# Output:
#     http_code, the HTTP code returned by Code Engine
#     message, the HTTP message returned by Code Engine
#
# Return:
#     200 if everything is OK, otherwise an error code with relative message
####################################################################################################
get_guid_from_reservation_id() {
    local jwt_token="$1"
    local result
    local http_status
    local response_message

    # This curl check if the input reservation id exists
    result=$(curl -s -w "%{http_code}" -o ${HTTP_OUTPUT_FILE} \
        -H "Authorization: Bearer ${jwt_token}" \
        "${HPC_API_ENDPOINT_URL}/${V3_CONTEXT_ROOT}/capacity_reservations")

    # The curl return a reply with the following format { ... JSON ... }HTTPSTATUS.
    # These two lines separate the HTTP STATUS from the JSON reply.
    http_status="${result: -3}"
    response_message=$(cat "${HTTP_OUTPUT_FILE}")

    # Show both the HTTP code and the response message
    echo "${http_status}"
    echo "${response_message}"
}

####################################################################################################
# check_reservation
#
# Description:
#     this function check if a Code Engine Project exists for the input reservation_id. If so,
#     the function return with success, otherwise an error is returned.
# Input:
#     jwt_token, the jwt token
#     reservation_guid, the reservation guid to check
# Output:
#     http_code, the HTTP code returned by Code Engine
#     message, the HTTP message returned by Code Engine
#
# Return:
#     200 if everything is OK, otherwise an error code with relative message
####################################################################################################
check_reservation() {
    local jwt_token="$1"
    local reservation_guid="$2"
    local result
    local http_status
    local response_message

    # This curl check if the input reservation id exists
    result=$(curl -s -w "%{http_code}" -o ${HTTP_OUTPUT_FILE} \
        -H "Authorization: Bearer ${jwt_token}" \
        "${CODE_ENGINE_API_ENDPOINT_URL}/${V2BETA_CONTEXT_ROOT}/capacity_reservations/${reservation_guid}")

    # The curl return a reply with the following format { ... JSON ... }HTTPSTATUS.
    # These two lines separate the HTTP STATUS from the JSON reply.
    http_status="${result: -3}"
    response_message=$(cat "${HTTP_OUTPUT_FILE}")

    # Show both the HTTP code and the response message
    echo "${http_status}"
    echo "${response_message}"
}

####################################################################################################
# create_ce_project
#
# Description:
#     this function creates a Code Engine Project.
# Input:
#     jwt_token, the jwt token
#     region, the region
#     resource_group_id, the resource group id
# Output:
#     http_code, the HTTP code returned by Code Engine
#     message, the HTTP message returned by Code Engine
# Return:
#     201 or 202 if everything is OK, otherwise an error code with relative message
####################################################################################################
create_ce_project() {
    local jwt_token="$1"
    local region="$2"
    local resource_group_id="$3"
    local timestamp
    local project_name
    local resource_plan_id
    local parameters
    local allow_cleanup
    local result
    local http_code
    local response_message

    timestamp=$(date "+%Y%m%d%H%M%S")
    project_name="HPC-Default-${timestamp}"
    resource_plan_id="814fb158-af9c-4d3c-a06b-c7da42392845"
    parameters='{"name":"'"${project_name}"'","profile":"hpc"}'
    allow_cleanup=false

    # This curl create an empty Code Engine project via Resource Controller
    result=$(curl -s -w "%{http_code}" -o ${HTTP_OUTPUT_FILE} \
        -X POST \
        -H "Authorization: Bearer ${jwt_token}" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"${project_name}\",\"resource_plan_id\":\"${resource_plan_id}\",\"resource_group\":\"${resource_group_id}\",\"parameters\":${parameters},\"target\":\"${region}\",\"allow_cleanup\":${allow_cleanup}}" \
        "${RESOURCE_CONTROLLER_ENDPOINT_URL}/${V2_CONTEXT_ROOT}/resource_instances")

    # The curl return a reply with the following format { ... JSON ... }HTTPSTATUS.
    # These two lines separate the HTTP STATUS from the JSON reply.
    http_code="${result: -3}"
    response_message=$(cat "${HTTP_OUTPUT_FILE}")

    # Show both the HTTP code and the response message
    echo "$http_code"
    echo "$response_message"
}

####################################################################################################
# wait_ce_project_creation
#
# Description:
#     this function waits the Code Engine Project was successfully created.
# Input:
#     guid, the Code Engine project guid
# Return:
#     0, successful
#     1, timeout expired
####################################################################################################
wait_ce_project_creation() {
    local jwt_token="$1"
    local region="$2"
    local ce_project_guid="$3"
    # 3 minutes and 20s timeout
    local timeout=200
    local start_time
    local http_code
    local response_message
    local status
    local current_time
    local elapsed_time
    local result

    start_time=$(date +%s)
    # Loop until the Code Engine project is ready or the timeout expired
    while true; do
        # Check if the Code Engine project is ready
        result=$(curl -s -w "%{http_code}" -o ${HTTP_OUTPUT_FILE} \
            -H "Authorization: Bearer ${jwt_token}" \
            "${CODE_ENGINE_API_ENDPOINT_URL}/${V2_CONTEXT_ROOT}/projects/${ce_project_guid}")

        # The curl return a reply with the following format { ... JSON ... }HTTPSTATUS.
        # These two lines separate the HTTP STATUS from the JSON reply.
        http_code="${result: -3}"
        response_message=$(cat "${HTTP_OUTPUT_FILE}")

        # If the Code Engine project is ready, return
        if [ "$http_code" -eq 200 ]; then
            status=$(jq -r '.status' "${HTTP_OUTPUT_FILE}")

            # If status is not active exit from this cycle, Code Engine API returns this status when the project is ready
            if [ "$status" == "active" ]; then
                return 0
            fi
        fi

        # Check if the timeout expired
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        if [ "$elapsed_time" -ge "$timeout" ]; then
            break
        fi

        # Wait 10 seconds before retry the check.
        sleep 10
    done

    # The Code Engine project wasn't successfully created, the timeout expired, so return error
    return 1
}

####################################################################################################
# associate_ce_project_to_reservation
#
# Description:
#     this function associates the Code Engine project to the HPC Reservation
# Input:
#     guid, the Code Engine project guid
# Return:
#     200 if everything is OK, otherwise an error code with relative message
####################################################################################################
associate_ce_project_to_reservation() {
    local jwt_token="$1"
    local region="$2"
    local ce_project_guid="$3"
    local reservation_guid="$4"
    local http_code
    local response_message

    # This Code Engine API associate the Reservation ID to the Code Engine project previously created
    result=$(curl -s -w "%{http_code}" -o "${HTTP_OUTPUT_FILE}" \
        -X PATCH \
        -H "Authorization: Bearer ${jwt_token}" \
        -H "Content-Type: application/json" \
        -d "{\"project_id\":\"${ce_project_guid}\"}" \
        "${CODE_ENGINE_API_ENDPOINT_URL}/${V2BETA_CONTEXT_ROOT}/projects/${ce_project_guid}/capacity_reservations/${reservation_guid}")

    # The curl return a reply with the following format { ... JSON ... }HTTPSTATUS.
    # These two lines separate the HTTP STATUS from the JSON reply.
    http_code="${result: -3}"
    response_message=$(cat "${HTTP_OUTPUT_FILE}")

    # Show both the HTTP code and the response message
    echo "${http_code}"
    echo "${response_message}"
}

####################################################################################################
# Main program
####################################################################################################
# First of all, let's parse the input parameters so that we have the input variables to work on.
# This parsing will populate the globa variables:
# - RESERVATION_ID
# - REGION
# - RESOURCE_GROUP_ID
# - LOG_FILE
parse_args "$@"

# The IBM tool https://github.com/ibm/detect-secrets detected a secret keyword.
# However, it detected only the API keyword but no real secret expure exists here.
if [ -z "$IBM_CLOUD_API_KEY" ]; then  # pragma: allowlist secret
    log "ERROR: environment variable IBM_CLOUD_API_KEY not provided. Run the command:"
    log "       export IBM_CLOUD_API_KEY=\"<your API Key>\"" # pragma: allowlist secret
    exit 1
fi

# Since I have now the value for the REGION variable I can set correctly the:
# - Code Engine API Endpoint URL correctly
# - HPC API Endpoint URL correctly
CODE_ENGINE_API_ENDPOINT_URL=${CODE_ENGINE_API_ENDPOINT_URL//REGION/${REGION}}
HPC_API_ENDPOINT_URL=${HPC_API_ENDPOINT_URL//REGION/${REGION}}

# Try to exchange the IBM Cloud API key for a JWT token.
log "INFO: Retrieving the JWT Token for the IBM_CLOUD_API_KEY."
if  ! JWT_TOKEN=$(get_token "${IBM_CLOUD_API_KEY}"); then
    HTTP_STATUS=$(echo "${JWT_TOKEN}" | head -n 1)
    ERROR_MESSAGE=$(echo "${JWT_TOKEN}" | tail -n 1)
    log "ERROR: cannot retrieve JWT token. HTTP Status ${HTTP_STATUS}. ${ERROR_MESSAGE}"
    exit 3
fi

# HPC Tile has the parameter RESERVATION_ID that is meaningful name like Contract-IBM-WDC-OB
# As first step, we need to get the RESERVATION_GUID starting from the RESERVATION_ID
log "INFO: Getting the Reservation GUID starting from the ID ${RESERVATION_ID}."
response=$(get_guid_from_reservation_id "${JWT_TOKEN}")
http_code=$(echo "${response}" | head -n 1)
response_message=$(echo "${response}" | tail -n +2)

# Check if the RESERVATION_GUID is available
if [ "${http_code}" != "200" ]; then
    log "ERROR: Reservation GUID for the ID ${RESERVATION_ID}, wasn't found."
    log "ERROR Details: ${response_message}."
    exit 4
fi

RESERVATION_GUID=$(echo "${response_message}" | jq -r ".capacity_reservations[] | select (.name == \"${RESERVATION_ID}\") | .id")
if [ -z "$RESERVATION_GUID" ]; then
    log "ERROR: Reservation GUID for the ID ${RESERVATION_ID}, wasn't found."
    exit 4
fi

log "INFO: Reservation (ID: ${RESERVATION_ID}) has the GUID: ${RESERVATION_GUID}."

# The first step is to validate the RESERVATION_ID and verify if a Code Engine Project exists for it.
log "INFO: Verifying the existence of a Reservation (GUID: ${RESERVATION_GUID})."
response=$(check_reservation "${JWT_TOKEN}" "${RESERVATION_GUID}")
http_code=$(echo "${response}" | head -n 1)
response_message=$(echo "${response}" | tail -n +2)

# Check if the a Code Engine Project relative to the RESERVATION ID was found in Code Engine
if [ "${http_code}" != "200" ]; then
    log "ERROR: Reservation with GUID ${RESERVATION_GUID}, wasn't found."
    log "ERROR Details: ${response_message}."
    exit 5
fi

# A Reservation with id RESERVATION_ID exists. We need to verify that a Code Engine project exists.
log "INFO: Verifying if the Reservation (GUID: ${RESERVATION_GUID}) is associated with a Code Engine project."

# Check if a project_id exists in the response_message
CODE_ENGINE_PROJECT_GUID=$(echo "${response_message}" | jq -e -r '.project_id // empty')
if [ -n "${CODE_ENGINE_PROJECT_GUID}" ]; then
    log "INFO: Reservation (GUID: ${RESERVATION_GUID}) exists and is associated with the Code Engine project (ID: ${CODE_ENGINE_PROJECT_GUID})."
    log "INFO: Write the Code Engine project (ID: ${CODE_ENGINE_PROJECT_GUID} in the ${CODE_ENGINE_PROJECT_GUID_FILE} file."
    echo -n "${CODE_ENGINE_PROJECT_GUID}" > "${CODE_ENGINE_PROJECT_GUID_FILE}"
    log "INFO: ${0} successfully completed."
    exit 0
fi

# A Reservation with id RESERVATION_ID exists but a Code Engine project doesn't, we need to create it.
log "INFO: No Code Engine project is associated with the Reservation (GUID: ${RESERVATION_GUID}). Initiating project creation."
response=$(create_ce_project "${JWT_TOKEN}" "${REGION}" "${RESOURCE_GROUP_ID}")
http_code=$(echo "${response}" | head -n 1)
response_message=$(echo "${response}" | tail -n +2)

# Check if the a Code Engine Project has been created
if [ "${http_code}" != "201" ] && [ "${http_code}" != "202" ]; then
    log "ERROR: Cannot create a Code Engine project."
    log "ERROR Details: ${response_message}."
    exit 6
fi

# If Code Engine project has been created, wait for its completion
CODE_ENGINE_PROJECT_GUID=$(echo "${response_message}" | jq -e -r '.guid')
log "INFO: Code Engine project (GUID: ${CODE_ENGINE_PROJECT_GUID}) for the Reservation (GUID: ${RESERVATION_GUID}) has been created. Waiting for its completion."
if  ! wait_ce_project_creation "${JWT_TOKEN}" "${REGION}" "${CODE_ENGINE_PROJECT_GUID}"; then
    log "ERROR: Code Engine project creation timeout expired."
    exit 7
fi

# We can associate the Code Engine project id to the Reservation
log "INFO: Code Engine project (GUID: ${CODE_ENGINE_PROJECT_GUID}) is going to be associated to the Reservation with GUID ${RESERVATION_GUID}."
response=$(associate_ce_project_to_reservation "${JWT_TOKEN}" "${REGION}" "${CODE_ENGINE_PROJECT_GUID}" "${RESERVATION_GUID}")
http_code=$(echo "${response}" | head -n 1)
response_message=$(echo "${response}" | tail -n +2)

# Check if the a Code Engine Project has been created
if [ "${http_code}" != "200" ]; then
    log "ERROR: Cannot associate the Code Engine project with guid ${CODE_ENGINE_PROJECT_GUID} to the Reservation with GUID ${RESERVATION_GUID}."
    log "ERROR Details: ${response_message}."
    exit 8
fi

log "INFO: Code Engine project (GUID: ${CODE_ENGINE_PROJECT_GUID}) has been successfully associated to the Reservation with GUID ${RESERVATION_GUID}."
log "INFO: Write the Code Engine project (ID: ${CODE_ENGINE_PROJECT_GUID} in the ${CODE_ENGINE_PROJECT_GUID_FILE} file."
echo -n "${CODE_ENGINE_PROJECT_GUID}" > "${CODE_ENGINE_PROJECT_GUID_FILE}"
log "INFO: ${0} successfully completed."
