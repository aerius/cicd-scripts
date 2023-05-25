#!/usr/bin/env bash

# Exit on error
set -e

# Record directory of script for convenience
SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

# Prepare stuff
source "${SCRIPT_DIR}"/../prepare/make_it_so.sh

# Do various validations
: ${DEPLOY_OTA_ENVIRONMENT_CICD_URL?'DEPLOY_OTA_ENVIRONMENT_CICD_URL is required'}
: ${DEPLOY_OTA_ENVIRONMENT_CICD_LOGIN?'DEPLOY_OTA_ENVIRONMENT_CICD_LOGIN is required'}
: ${JOB_NAME?'JOB_NAME is required'}
: ${BUILD_NUMBER?'BUILD_NUMBER is required'}
: ${GIT_COMMIT?'GIT_COMMIT is required'}
: ${GIT_URL?'GIT_URL is required'}
: ${AERIUS_REGISTRY_URL?'AERIUS_REGISTRY_URL is required'}

# Trigger CICD to do the deploy
curl \
  --user "${DEPLOY_OTA_ENVIRONMENT_CICD_LOGIN}" \
  --data SOURCE_JOB_NAME="${JOB_NAME}" \
  --data SOURCE_JOB_BUILD_NUMBER="${BUILD_NUMBER}" \
  --data GIT_COMMIT="${GIT_COMMIT}" \
  --data GIT_URL="${GIT_URL}" \
  --data AERIUS_REGISTRY_URL="${AERIUS_REGISTRY_URL}" \
  "${DEPLOY_OTA_ENVIRONMENT_CICD_URL}"
