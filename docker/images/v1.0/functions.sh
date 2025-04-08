#!/usr/bin/env bash

# import tools dir - SCRIPT_DIR is set before this is sourced
source "${CICD_SCRIPTS_DIR}"/set_cicd_scripts_tools_dir.envsh

# Directory to put generated theme/files in
GENERATED_DIRECTORY='generated'

# docker-compose.yaml path
DOCKER_COMPOSE_PATH="${GENERATED_DIRECTORY}/docker-compose.yaml"

# Custom profile filename
CUSTOM_PROFILE_FILENAME='custom.profile'

# function to print error and exit
# $1 = error message
function _cicd_error() {
  echo '[CICD-ERROR]['$(date +'%H:%M:%S')'] - '"${1}"
  exit 1
}

# function to log a message
# $1 = message to log
function _cicd_log() {
  echo '[CICD-INFO]['$(date +'%H:%M:%S')'] - '"${1}"
}


# function to check if a module is enabled
# $1 = contains modules that are enabled separated by space or empty/not set which means all modules are enabled
# $2 = module(s) to check for, multiple can be provided by using spaces
function _cicd_is_module_enabled() {
  [[ -z "${1}" ]] && return 0

  for module in ${2}; do
    [[ "${1}" == *" ${module} "* ]] && return 0
  done

  return 1
}

# function to copy a block of yaml into the resulting yaml
# $1 = yaml to copy to
# $2 = yaml to copy from
# $3 = root name to copy (services/volumes etc)
# $4 = entry to copy over (service name, volume name etc)
function _cicd_copy_yaml_block_into() {
  local TEMPFILE="${GENERATED_DIRECTORY}/${3}.${4}.yaml"
  touch "${TEMPFILE}"

  "${CICD_SCRIPTS_TOOLS_DIR}"/yq '{"'"${3}"'": {"'"${4}"'": .'"${3}"'.'"${4}"' }}' "${2}" > "${TEMPFILE}"
  "${CICD_SCRIPTS_TOOLS_DIR}"/yq -i '. *= load ("'"${TEMPFILE}"'")' "${1}"
}

function _cicd_read_in_config() {
  if [[ -f .cicd_scripts_config ]]; then
    _cicd_log 'Reading in CICD config found in current directory'
    source .cicd_scripts_config
  else
    _cicd_log 'No CICD config found.. Using defaults..'
  fi
}
