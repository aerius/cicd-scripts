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
# A PR for calculator will have a job name of "CALCULATOR-PR" (based on repository name) and the build number will be the PR ID
if [[ -n "${PULLREQUEST_ID}" ]]; then
  JOB_NAME="${GIT_URL##*/}"
  JOB_NAME="${JOB_NAME%%.git}"
  JOB_NAME="${JOB_NAME^^}-PR"

  BUILD_NUMBER="${PULLREQUEST_ID}"
# For our custom temporary builds, use the proper environment name
elif [[ "${JOB_NAME}" == 'STIKSTOFJE-DEPLOY-OTA-ENVIRONMENT' ]]; then
  JOB_NAME="${ENVIRONMENT_NAME}"
fi

# Jobs starting with UK-, should use the UK account by default, if already set, that has precedence
if [[ -z "${AWS_ACCOUNT_NAME}" ]] && [[ "${JOB_NAME}" == UK-* ]]; then
  AWS_ACCOUNT_NAME='UK-DEV'
fi

# If REQUESTED_BY_USER is not set and the job is triggered by a user, use this as the requester
if [[ -z "${REQUESTED_BY_USER}" ]] && [[ -n "${BUILD_USER_ID}" ]] && [[ "${BUILD_USER_ID}" != 'ota-environment-deploy' ]]; then
  REQUESTED_BY_USER="${BUILD_USER_ID}"
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
  ${AWS_ACCOUNT_NAME:+--data AWS_ACCOUNT_NAME="${AWS_ACCOUNT_NAME}"} \
  ${FLAGS:+--data FLAGS="${FLAGS}"} \
  ${MATTERMOST_CHANNEL:+--data MATTERMOST_CHANNEL="${MATTERMOST_CHANNEL}"} \
  ${REQUESTED_BY_USER:+--data REQUESTED_BY_USER="${REQUESTED_BY_USER}"} \
  ${DRY_RUN:+--data DEPLOY_TERRAFORM_ACTION='dry-run'} \
  ${CICD_JOB_MESSAGES:+--data CICD_JOB_MESSAGES="${CICD_JOB_MESSAGES}"} \
  "${DEPLOY_OTA_ENVIRONMENT_CICD_URL}"
