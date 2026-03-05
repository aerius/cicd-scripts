#!/usr/bin/env bash

# This prescript is superseded by images_v*.sh, but is still there for backwards compatibility

# Exit on error
set -e

# Tools needed for this script to function
export CICD_SCRIPTS_TOOL_YQ=true

# Record directory of script for convenience
SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

# Prepare stuff
source "${SCRIPT_DIR}"/../prepare/make_it_so.envsh

# no-op, might be used in older places, but this script isn't needed anymore
