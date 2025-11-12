#!/usr/bin/env bash

# Exit on error
set -e

if ! [[ -x "${CICD_SCRIPTS_TOOLS_DIR}"/yq ]]; then
  echo '[prepare] # Installing yq'
  curl --output "${CICD_SCRIPTS_TOOLS_DIR}"/yq -L https://github.com/mikefarah/yq/releases/download/"${CICD_SCRIPTS_YQ_VERSION}"/yq_linux_"${CICD_SCRIPTS_TOOLS_ARCH}"
  chmod u+x "${CICD_SCRIPTS_TOOLS_DIR}"/yq
else
  echo '[prepare] # yq is already installed, skipping install.'
fi

# Print version
"${CICD_SCRIPTS_TOOLS_DIR}"/yq --version
echo
