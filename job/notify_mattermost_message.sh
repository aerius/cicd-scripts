#!/usr/bin/env bash

# Exit on error
set -e

function notify_mattermost_message_add_label() {
  echo '![label_'"${1}"'](https://nexus.aerius.nl/repository/resources/images/label_'"${1}"'.png)'
}

MSG_TITLE="[${BUILD_DISPLAY_NAME^^}](${BUILD_URL})"
if [[ "${JOB_NAME}" == 'DEPLOY-OTA-ENVIRONMENT' ]]; then
  MSG_TITLE+=' '$(notify_mattermost_message_add_label 'deploy')
  if [[ -n "${DEPLOY_TERRAFORM_ACTION}" ]]; then
    MSG_TITLE+=' '$(notify_mattermost_message_add_label "${DEPLOY_TERRAFORM_ACTION}")
  fi
else
  MSG_TITLE+=' '$(notify_mattermost_message_add_label 'build')
fi

MSG_FOOTER=
[[ -n "${REQUESTED_BY_USER}" ]] && MSG_FOOTER="CC: @${REQUESTED_BY_USER}"

echo -n "${MSG_TITLE}
The build finished with status \`${1}\` in \`${2%and counting}\`.
${MSG_FOOTER}"
