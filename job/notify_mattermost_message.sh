#!/usr/bin/env bash

# Exit on error
set -e

MESSAGE="${BUILD_DISPLAY_NAME}"
if [[ "${JOB_NAME}" == 'DEPLOY-OTA-ENVIRONMENT' ]]; then
  MESSAGE+=' [deploy]'
else
  MESSAGE+=' [build]'
fi

echo -n "${MESSAGE}"
