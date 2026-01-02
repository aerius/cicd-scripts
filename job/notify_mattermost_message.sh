#!/usr/bin/env bash

# Exit on error
set -e

# Record directory of script for convenience
SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

function notify_mattermost_message_add_label() {
  echo '!['"${1}"'](https://nexus.aerius.nl/repository/resources/images/label_'"${1}"'.png)'
}

function notify_mattermost_message_get_url_for_environment() {
  SUBDOMAIN_NAME="${1}"
  DOMAIN='nl'

  [[ "${SUBDOMAIN_NAME}" == 'QA-'* ]] && SUBDOMAIN_NAME="${SUBDOMAIN_NAME#QA-}"
  [[ "${SUBDOMAIN_NAME}" == 'UK-'* ]] && SUBDOMAIN_NAME="${SUBDOMAIN_NAME#UK-}" && DOMAIN='uk'
  echo "https://${SUBDOMAIN_NAME,,}.aerius.${DOMAIN}"
}

function notify_mattermost_message_add_msg_icon() {
  MSG_ICONS+="[:${1}:](${2}) "
}

# Default title and action
MSG_TITLE="[${JOB_NAME} ${BUILD_DISPLAY_NAME}](${BUILD_URL})"
MSG_ICONS=
MSG_ACTION='build'

# If BUILD_DISPLAY_NAME contains a space, it's a custom one, use that instead
[[ "${BUILD_DISPLAY_NAME}" == *' '* ]] && MSG_TITLE="[${BUILD_DISPLAY_NAME^^}](${BUILD_URL})"

if [[ "${JOB_NAME}" == 'DEPLOY-OTA-ENVIRONMENT' ]]; then
  MSG_TITLE+=' '$(notify_mattermost_message_add_label 'deploy')
  if [[ -n "${DEPLOY_TERRAFORM_ACTION}" ]]; then
#    MSG_TITLE+=' '$(notify_mattermost_message_add_label "${DEPLOY_TERRAFORM_ACTION}")
    MSG_ACTION="${DEPLOY_TERRAFORM_ACTION}"
  fi
elif [[ "${JOB_NAME}" == 'QA-GENERIC' ]]; then
  MSG_TITLE="[Manual QA-run on ${SOURCE_JOB_NAME}](${BUILD_URL})"
elif [[ "${JOB_NAME}" == 'QA-'* ]]; then
  :
else
  MSG_TITLE+=' '$(notify_mattermost_message_add_label 'build')
fi

MSG_JOB_MESSAGES=
if [[ -n "${CICD_JOB_MESSAGES}" || -n "${3}" ]]; then
  # Add the current job to the durations as well if specified
  [[ -n "${3}" ]] && CICD_JOB_MESSAGES=$("${SCRIPT_DIR}"/add_job_duration.sh "${3}" "${2%and counting}")
  MSG_JOB_MESSAGES+='```
'
  while read -d ';' MSG_TYPE MSG_CONTENT; do
    case "${MSG_TYPE,,}" in
      message)
        MSG_JOB_MESSAGES+="${MSG_CONTENT}"'
'
        ;;
      jobduration)
        read JOB_DURATION_TYPE JOB_DURATION <<< "${MSG_CONTENT}"
        MSG_JOB_MESSAGES+=$(printf '%-8s job took %s' "${JOB_DURATION_TYPE^}" "${JOB_DURATION}")'
'
        ;;
    esac
  done <<< "${CICD_JOB_MESSAGES};"

  MSG_JOB_MESSAGES+='```
'
  [[ "${1}" == 'ABORTED' ]] && MSG_JOB_MESSAGES+="Job was aborted"
  # New way of detecting a crashed stage based on generic pipeline
  [[ "${1}" == 'FAILURE' ]] && [[ -n "${CICD_CRASHED_STAGE}" ]] && MSG_JOB_MESSAGES+='Job crashed in stage `'"${CICD_CRASHED_STAGE}"'`'
  # Old way of detecting a crashed stage based on manual magic
  [[ "${1}" == 'FAILURE' ]] && [[ -z "${CICD_CRASHED_STAGE}" ]] && MSG_JOB_MESSAGES+='Job crashed in stage `'"${CICD_LAST_STARTED_STAGE:-Unknown}"'`'
# We use the fallback message if it's an older one
else
  MSG_JOB_MESSAGES+="The \`${MSG_ACTION}\` finished with status \`${1}\` in \`${2%and counting}\`"
fi

MSG_FOOTER=
[[ -n "${BUILD_USER_ID}" ]] && [[ ' ota-environment-deploy timer ' != *" ${BUILD_USER_ID} "* ]] && MSG_FOOTER+="Job was manually triggered by @${BUILD_USER_ID}
"
if [[ "${BUILD_DISPLAY_NAME}" == *' '* ]] && [[ "${MSG_ACTION}" == 'apply' ]] && [[ "${1}" == 'SUCCESS' ]]; then
  CUSTOM_JOB_NAME="${BUILD_DISPLAY_NAME%% *}"
  notify_mattermost_message_add_msg_icon 'aerius' $(notify_mattermost_message_get_url_for_environment "${CUSTOM_JOB_NAME}")
fi
if [[ -n "${REQUESTED_BY_USER}" ]]; then
  REQUESTED_BY_USER="${REQUESTED_BY_USER#@}"
  # Add @ after comma, if it is missing
  REQUESTED_BY_USER=$(sed -E 's/,([a-zA-Z])/,@\1/g'<<<"${REQUESTED_BY_USER}")
  # If REQUESTED_BY_USER is the same as the user who triggered the build manually, don't mention the CC
  if [[ "${REQUESTED_BY_USER}" != "${BUILD_USER_ID}" ]]; then
    MSG_FOOTER+="CC: @${REQUESTED_BY_USER}"
  fi
fi
if [[ "${JOB_NAME}" == 'QA-'* ]] && [[ "${1}" == 'SUCCESS' || "${1}" == 'UNSTABLE' ]]; then
  if [[ "${JOB_NAME}" == 'QA-GENERIC' ]]; then
    notify_mattermost_message_add_msg_icon 'aerius' $(notify_mattermost_message_get_url_for_environment "${SOURCE_JOB_NAME}")
  else
    notify_mattermost_message_add_msg_icon 'aerius' $(notify_mattermost_message_get_url_for_environment "${JOB_NAME}")
  fi
  notify_mattermost_message_add_msg_icon 'java' "${BUILD_URL}testReport/"
  notify_mattermost_message_add_msg_icon 'cucumber_reports' "${BUILD_URL}cucumber-html-reports/"
fi

echo -n "${MSG_TITLE} ${MSG_ICONS}
${MSG_JOB_MESSAGES}
${MSG_FOOTER}"
