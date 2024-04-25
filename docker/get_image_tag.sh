#!/usr/bin/env bash

# Exit on error
set -e

if [[ -n "${PULLREQUEST_ID}" ]]; then
  [[ -n "${GIT_COMMIT}" ]] && IMAGE_TAG_EXTRA=$(cut -c 1-8 <<< "${GIT_COMMIT}")
  [[ -z "${IMAGE_TAG_EXTRA}" ]] && IMAGE_TAG_EXTRA=$(date +'%Y-%m-%d-%H-%M')
  echo -n "pr-${PULLREQUEST_ID}_${IMAGE_TAG_EXTRA}"
else
  # Check whether the required JOB_BASE_NAME is set
  : ${BUILD_NUMBER?'BUILD_NUMBER is required for this script to function'}

  echo -n "build-${BUILD_NUMBER}_"$(date +'%Y-%m-%d-%H-%M')
fi
