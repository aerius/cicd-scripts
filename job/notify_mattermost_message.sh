#!/usr/bin/env bash

# Exit on error
set -e

function notify_mattermost_message_add_label() {
  echo '!['"${1}"'](https://nexus.aerius.nl/repository/resources/images/label_'"${1}"'.png)'
}

# Default title and action
MSG_TITLE="[${JOB_NAME} ${BUILD_DISPLAY_NAME}](${BUILD_URL})"
MSG_ACTION='build'

# If BUILD_DISPLAY_NAME contains a space, it's a custom one, use that instead
[[ "${BUILD_DISPLAY_NAME}" == *' '* ]] && MSG_TITLE="[${BUILD_DISPLAY_NAME^^}](${BUILD_URL})"

if [[ "${JOB_NAME}" == 'DEPLOY-OTA-ENVIRONMENT' ]]; then
  MSG_TITLE+=' '$(notify_mattermost_message_add_label 'deploy')
  if [[ -n "${DEPLOY_TERRAFORM_ACTION}" ]]; then
#    MSG_TITLE+=' '$(notify_mattermost_message_add_label "${DEPLOY_TERRAFORM_ACTION}")
    MSG_ACTION="${DEPLOY_TERRAFORM_ACTION}"
  fi
elif [[ "${JOB_NAME}" == 'QA-'* ]]; then
  :
else
  MSG_TITLE+=' '$(notify_mattermost_message_add_label 'build')
fi

MSG_FOOTER=
if [[ "${BUILD_DISPLAY_NAME}" == *' '* ]] && [[ "${MSG_ACTION}" == 'apply' ]] && [[ "${1}" == 'SUCCESS' ]]; then
  CUSTOM_JOB_NAME="${BUILD_DISPLAY_NAME%% *}"
  ENVIRONMENT_URL="https://${CUSTOM_JOB_NAME}.aerius.nl"
  [[ "${CUSTOM_JOB_NAME}" == 'UK-'* ]] && ENVIRONMENT_URL="https://${CUSTOM_JOB_NAME#UK-}.aerius.uk"
  MSG_FOOTER+="[Click to go to this environment](${ENVIRONMENT_URL,,})
"
fi
if [[ -n "${REQUESTED_BY_USER}" ]]; then
  REQUESTED_BY_USER="${REQUESTED_BY_USER#@}"
  # Add @ after comma, if it is missing
  REQUESTED_BY_USER=$(sed -E 's/,([a-zA-Z])/,@\1/g'<<<"${REQUESTED_BY_USER}")
  MSG_FOOTER+="CC: @${REQUESTED_BY_USER}"
fi

echo -n "${MSG_TITLE}
The \`${MSG_ACTION}\` finished with status \`${1}\` in \`${2%and counting}\`.
${MSG_FOOTER}"
