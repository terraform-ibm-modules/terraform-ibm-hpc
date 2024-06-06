#!/bin/bash
#
# Licensed Materials - Property of IBM
# 5725-S00 (C) Copyright IBM Corp. 2024. All Rights Reserved.
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
SCRIPT_DIR=$(realpath "$(dirname "$0")")
TMP_DIR="/tmp"
LOG_FILE="${TMP_DIR}/hpcaas-check-reservation.log"
CODE_ENGINE_PROJECT_GUID=""

LOG_OUTPUT=$("${SCRIPT_DIR}"/check_reservation.sh --region "${REGION}" --resource-group-id "${RESOURCE_GROUP_ID}" --output "${LOG_FILE}" 2>&1)
RETURN_CODE=$?

if [ ${RETURN_CODE} -eq 0 ]; then
  # Estract the row containing CODE_ENGINE_PROJECT_GUID
  GUID_LINE=$(echo "${LOG_OUTPUT}" | grep "CODE_ENGINE_PROJECT_GUID")
  # If that line exists, extract the CE Project GUID
  if [ -n "${GUID_LINE}" ]; then
      CODE_ENGINE_PROJECT_GUID=$(echo "$GUID_LINE" | awk -F'=' '{print $2}')
  fi
fi

JSON_OUTPUT=$(printf '{
  "guid": "%s",
  "logs": "%s"
}' "${CODE_ENGINE_PROJECT_GUID}" "${LOG_OUTPUT}")

echo "${JSON_OUTPUT}"
exit ${RETURN_CODE}
