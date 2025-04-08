#!/usr/bin/env bash

# Exit on error
set -e

# Change current directory to directory of script so it can be called from everywhere
SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

# include functions
source "${SCRIPT_DIR}"/functions.sh

#####################
### The real deal ###
#####################

_cicd_log '# List local images before push to show container image size'
docker images | grep -F -e "${AERIUS_REGISTRY_URL}" -e REPOSITORY
# Push images
_cicd_log '# Pushing images'
"${CICD_SCRIPTS_TOOLS_DIR}"/docker-compose -f "${DOCKER_COMPOSE_PATH}" --project-directory "${GENERATED_DIRECTORY}" push --quiet
_cicd_log '# Finished pushing images'
