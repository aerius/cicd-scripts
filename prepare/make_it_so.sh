#!/usr/bin/env bash

# Exit on error
set -e

# Change current directory to directory of script so it can be called from everywhere
SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")
pushd "${SCRIPT_DIR}"

# Tool versions
export CICD_SCRIPTS_YQ_VERSION=v4.34.1

# Go to root of repository
cd ..
export CICD_SCRIPTS_TOOLS_DIR=$(pwd)/.bin

# Create tools directory if needed
mkdir -p "${CICD_SCRIPTS_TOOLS_DIR}"

# Go back to the prepare directory
cd prepare
# Install tools
[[ "${CICD_SCRIPTS_TOOL_YQ}" == 'true' ]] && ./prepare-install-jq.sh

# Pro tip: add CICD_SCRIPTS_TOOLS_DIR to your PATH - well, for security reasons might want to directly call these binaries instead, but yeah.
# Do what feels okay to you.

# Go back to previous directory
popd
