#!/usr/bin/env bash

# Exit on error
set -e

# Tools needed for this script to function
export CICD_SCRIPTS_TOOL_DOCKER_COMPOSE=true
export CICD_SCRIPTS_TOOL_YQ=true

# Record directory of script for convenience
SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

# Prepare stuff
source "${SCRIPT_DIR}"/../prepare/make_it_so.envsh

# Prepare code/dependencies/docker templates and such
"${SCRIPT_DIR}"/images/v1.0/prepare.sh
"${SCRIPT_DIR}"/images/v1.0/build.sh "${@}"
