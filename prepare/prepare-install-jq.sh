#!/usr/bin/env bash

# Exit on error
set -e

# Change current directory to directory of script so it can be called from everywhere
SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")
pushd "${SCRIPT_DIR}"

if ! [[ -x "${CICD_SCRIPTS_TOOLS_DIR}"/yq ]]; then
  echo '[prepare] # Installing yq'
  curl --output "${CICD_SCRIPTS_TOOLS_DIR}"/yq -L https://github.com/mikefarah/yq/releases/download/"${CICD_SCRIPTS_YQ_VERSION}"/yq_linux_amd64
  chmod u+x "${CICD_SCRIPTS_TOOLS_DIR}"/yq
else
  echo '[prepare] # yq is already installed, skipping install.'
fi

# Print version
"${CICD_SCRIPTS_TOOLS_DIR}"/yq --version
echo

# Go back to previous directory
popd
