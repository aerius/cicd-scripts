#!/usr/bin/env bash

# Exit on error
set -e

if [[ -n "${PULLREQUEST_ID}" ]]; then
  echo -n "pr-${PULLREQUEST_ID}"
else
  # Check whether the required JOB_BASE_NAME is set
  : ${BUILD_NUMBER?'BUILD_NUMBER is required for this script to function'}

  echo -n "build-${BUILD_NUMBER}"
fi
