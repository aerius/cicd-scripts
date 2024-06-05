#!/usr/bin/env bash

# Exit on error
set -e

if [[ -n "${PULLREQUEST_ID}" ]]; then
  # Check whether the required PULLREQUEST_REPOSITORY is set
  : ${PULLREQUEST_REPOSITORY?'PULLREQUEST_REPOSITORY is required for this script to function'}

  echo -n "pullrequest-builder/${PULLREQUEST_REPOSITORY,,}"
elif [[ "${JOB_NAME}" == 'STIKSTOFJE-DEPLOY-OTA-ENVIRONMENT' ]]; then
  # Check whether the required ENVIRONMENT_NAME is set
  : ${ENVIRONMENT_NAME?'ENVIRONMENT_NAME is required for this script to function'}

  echo -n "temporary-custom/${ENVIRONMENT_NAME,,}"
else
  # Check whether the required JOB_BASE_NAME is set
  : ${JOB_BASE_NAME?'JOB_BASE_NAME is required for this script to function'}

  echo -n "${JOB_BASE_NAME,,}"
fi
