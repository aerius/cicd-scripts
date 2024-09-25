#!/usr/bin/env bash

# Exit on error
set -e

if [[ -n "${PULLREQUEST_ID}" ]]; then
  # Check whether the required PULLREQUEST_REPOSITORY is set
  : ${PULLREQUEST_REPOSITORY?'PULLREQUEST_REPOSITORY is required for this script to function'}

  echo -n "${PULLREQUEST_REPOSITORY^^} PR#${PULLREQUEST_ID}"
elif [[ "${JOB_NAME}" == 'STIKSTOFJE-DEPLOY-OTA-ENVIRONMENT' ]]; then
  # Check whether the required vars are set
  : ${ENVIRONMENT_NAME?'ENVIRONMENT_NAME is required for this script to function'}
  : ${BUILD_NUMBER?'BUILD_NUMBER is required for this script to function'}

  echo -n "${ENVIRONMENT_NAME} #${BUILD_NUMBER}"
elif [[ -z "${SOURCE_JOB_NAME}" ]]; then
  # Check whether the required vars are set
  : ${JOB_NAME?'JOB_NAME is required for this script to function'}
  : ${BUILD_NUMBER?'BUILD_NUMBER is required for this script to function'}

  echo -n "${JOB_NAME^^} #${BUILD_NUMBER}"
else
  # Check whether the required vars are set
  : ${SOURCE_JOB_NAME?'SOURCE_JOB_NAME is required for this script to function'}
  : ${SOURCE_JOB_BUILD_NUMBER?'SOURCE_JOB_BUILD_NUMBER is required for this script to function'}

  echo -n "${SOURCE_JOB_NAME^^} #${SOURCE_JOB_BUILD_NUMBER}"
fi

# if terraform action executed is not apply add it to the build name to make it stand out
[[ -n "${DEPLOY_TERRAFORM_ACTION}" && "${DEPLOY_TERRAFORM_ACTION}" != 'apply' ]] && echo -n " [${DEPLOY_TERRAFORM_ACTION^^}]" || true
