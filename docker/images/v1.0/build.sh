#!/usr/bin/env bash

# Exit on error
set -e

# Record directory of script for convenience
SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

# include functions
source "${SCRIPT_DIR}"/functions.sh

# Set variables we will re-use multiple times
PROFILE_PATH="${GENERATED_DIRECTORY}/${CUSTOM_PROFILE_FILENAME}"
DOCKER_COMPOSE_ORIGINAL_PATH="${GENERATED_DIRECTORY}/docker-compose-original.yaml"

# Set variable with whether the custom profile file is found
[[ -f "${PROFILE_PATH}" ]] && PROFILE_PATH_FOUND=0 || PROFILE_PATH_FOUND=1

####################
### Validations ###
###################

# Check if a custom theme exists
if ! ( [[ -d "${GENERATED_DIRECTORY}" ]] || [[ -f "${DOCKER_COMPOSE_ORIGINAL_PATH}" ]] ); then
  _cicd_error 'Generated directory not found. Use the prepare script to generate one first.'
fi

# Read in profile if it exists
[[ "${PROFILE_PATH_FOUND}" == 0 ]] && source "${PROFILE_PATH}"

# Read in CICD config if it exists
_cicd_read_in_config

# If a database is being built HTTPS_DATA_USERNAME/PASSWORDS are required
if [[ "${CICD_CONFIG_USES_DATABASE_BUILD}" == 'true' ]] && [[ "${PROFILE_PATH_FOUND}" == 1 || "${SERVICES[*]}" == *database* ]]; then
  : ${HTTPS_DATA_USERNAME?'ENV variable HTTPS_DATA_USERNAME is required if a database needs to be built'}
  : ${HTTPS_DATA_PASSWORD?'ENV variable HTTPS_DATA_PASSWORD is required if a database needs to be built'}

  CICD_SUPPLY_HTTPS_DATA='true'
# Just overwriting it, because we don't know what people do in repositories..
# I mean nothing will blow up if they would set this.. but.. :shrug:
else
  CICD_SUPPLY_HTTPS_DATA='false'
fi

#####################
### The real deal ###
#####################

# Dump processed docker-compose.yaml
echo '# Dump processed docker-compose.yaml'
"${CICD_SCRIPTS_TOOLS_DIR}"/docker-compose -f "${DOCKER_COMPOSE_ORIGINAL_PATH}" --project-directory "${GENERATED_DIRECTORY}" config > "${DOCKER_COMPOSE_PATH}"
echo

cat "${DOCKER_COMPOSE_PATH}"
# Build images
echo '# Building images'
CICD_COMPOSE_EXTRA_ARGS=()
[[ "${CICD_SUPPLY_HTTPS_DATA}" == 'true' ]] && CICD_COMPOSE_EXTRA_ARGS+=('--build-arg' 'HTTPS_DATA_USERNAME='"${HTTPS_DATA_USERNAME}" '--build-arg' 'HTTPS_DATA_PASSWORD='"${HTTPS_DATA_PASSWORD}")
"${CICD_SCRIPTS_TOOLS_DIR}"/docker-compose -f "${DOCKER_COMPOSE_PATH}" --project-directory "${GENERATED_DIRECTORY}" build --pull --parallel ${CICD_COMPOSE_EXTRA_ARGS[@]}
