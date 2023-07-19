#!/usr/bin/env bash

# Exit on error
set -e

# Record directory of script for convenience
SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

# Prepare stuff
source "${SCRIPT_DIR}"/../prepare/make_it_so.envsh

# Do various validations
: ${DEPLOY_OTA_ENVIRONMENT_CICD_URL?'DEPLOY_OTA_ENVIRONMENT_CICD_URL is required'}
: ${DEPLOY_OTA_ENVIRONMENT_CICD_LOGIN?'DEPLOY_OTA_ENVIRONMENT_CICD_LOGIN is required'}
: ${JOB_NAME?'JOB_NAME is required'}
: ${BUILD_NUMBER?'BUILD_NUMBER is required'}
: ${GIT_COMMIT?'GIT_COMMIT is required'}
: ${AERIUS_REGISTRY_URL?'AERIUS_REGISTRY_URL is required'}
: ${AERIUS_IMAGE_TAG?'AERIUS_IMAGE_TAG is required'}

# Get git URL from config, as this will contain the end result instead of posssibly variables that are replaced by Jenkins.
# The PR builder for example uses dynamic git URLs.
GIT_URL=$(git config remote.origin.url)

# For PR's we will do some slight modifications
if [[ -n "${PULLREQUEST_ID}" ]]; then
  JOB_NAME="${GIT_URL##*/}"
  JOB_NAME="${JOB_NAME%%.git}"
  JOB_NAME="${JOB_NAME^^}-PR"

  BUILD_NUMBER="${PULLREQUEST_ID}"
fi

# Trigger CICD to do the deploy
curl \
  --user "${DEPLOY_OTA_ENVIRONMENT_CICD_LOGIN}" \
  --data SOURCE_JOB_NAME="${JOB_NAME}" \
  --data SOURCE_JOB_BUILD_NUMBER="${BUILD_NUMBER}" \
  --data DEPLOY_GIT_COMMIT="${GIT_COMMIT}" \
  --data DEPLOY_GIT_URL="${GIT_URL}" \
  --data AERIUS_REGISTRY_URL="${AERIUS_REGISTRY_URL}" \
  --data DEPLOY_IMAGE_TAG="${AERIUS_IMAGE_TAG}" \
  ${SERVICE_TYPE:+--data SERVICE_TYPE="${SERVICE_TYPE}"} \
  ${SERVICE_THEME:+--data SERVICE_THEME="${SERVICE_THEME}"} \
  ${AWS_ACCOUNT_NAME:--data AWS_ACCOUNT_NAME="${AWS_ACCOUNT_NAME}"} \
  "${DEPLOY_OTA_ENVIRONMENT_CICD_URL}"
