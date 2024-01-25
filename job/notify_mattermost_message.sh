#!/usr/bin/env bash

# Exit on error
set -e

MSG_TITLE="[${BUILD_DISPLAY_NAME^^}](${BUILD_URL})"
if [[ "${JOB_NAME}" == 'DEPLOY-OTA-ENVIRONMENT' ]]; then
  MSG_TITLE+=' [deploy]'
else
  MSG_TITLE+=' [build]'
fi

MSG_FOOTER=
[[ -n "${REQUESTED_BY_USER}" ]] && MSG_FOOTER="CC: @${REQUESTED_BY_USER}"

echo -n "${MSG_TITLE}
The build finished with status \`${1}\` in \`${2%and counting}\`.
${MSG_FOOTER}"
