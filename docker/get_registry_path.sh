#!/usr/bin/env bash

# Exit on error
set -e

if [[ -n "${PULLREQUEST_ID}" ]]; then
  # Check whether the required PULLREQUEST_REPOSITORY is set
  : ${PULLREQUEST_REPOSITORY?'PULLREQUEST_REPOSITORY is required for this script to function'}

  echo -n "pullrequests-${PULLREQUEST_REPOSITORY,,}"
else
  # Check whether the required JOB_BASE_NAME is set
  : ${JOB_BASE_NAME?'JOB_BASE_NAME is required for this script to function'}

  echo -n "${JOB_BASE_NAME,,}"
fi
