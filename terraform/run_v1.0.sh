#!/usr/bin/env bash

# Exit on error
set -e

# Record directory of script for convenience
SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

# Prepare stuff
source "${SCRIPT_DIR}"/../prepare/make_it_so.sh

# Check whether the required vars are set
: ${SOURCE_JOB_NAME?'SOURCE_JOB_NAME is required for this script to function'}
: ${SOURCE_JOB_BUILD_NUMBER?'SOURCE_JOB_BUILD_NUMBER is required for this script to function'}
: ${GIT_COMMIT?'GIT_COMMIT is required for this script to function'}
: ${GIT_URL?'GIT_URL is required for this script to function'}
: ${AERIUS_REGISTRY_URL?'AERIUS_REGISTRY_URL is required for this script to function'}

echo "[terraform/run] # Going to do a terraform build for: ${SOURCE_JOB_NAME} #${SOURCE_JOB_BUILD_NUMBER}"

cd "${WORKSPACE}"

ENVIRONMENTS_DIRECTORY='environments'
ENV_NAME_UPPERCASE="${SOURCE_JOB_NAME}"
ENV_NAME="${SOURCE_JOB_NAME,,}"
ENV_ROOT_DIR="${ENVIRONMENTS_DIRECTORY}/${ENV_NAME}"

if [[ -d "${ENV_ROOT_DIR}" ]]; then
  echo '[terraform/run] # Environment directory "'"${ENV_ROOT_DIR}"'" already exists, quitting..'
  exit 1
fi

# Create environment root dir
mkdir -p "${ENV_ROOT_DIR}"

# Write modules.json
cat << EOF > "${ENV_ROOT_DIR}/modules.json"
[
  {
    "url": "${GIT_URL}",
    "version": "${GIT_COMMIT}",
    "checkout_path": "terraform"
  }
]
EOF

# Get environment modules
TERRAFORM_ENVIRONMENT="${ENV_NAME}" scripts/prepare-modules.sh

# Write account.terragrunt.hcl
cat << EOF > "${ENV_ROOT_DIR}/account.terragrunt.hcl"
locals {
  account_name      = "DEV"
  account_id        = "266046282533"
  aws_profile       = "dev"
}
EOF

# Write start of environment.terragrunt.hcl
cat << EOF > "${ENV_ROOT_DIR}/environment.terragrunt.hcl"
locals {
  environment       = "${ENV_NAME_UPPERCASE}"
  environment_short = "CAL-DEV"
  service = {
    "code"  = "CAL-DEV"
    "type"  = "DEV"
    "theme" = "WNB"
  }
  tf_bucket_key_prefix = "environments/${ENV_NAME}/"
  app_version = "latest"
  ecr_directory = "${ENV_NAME}"

  cognito_enabled                    = true
  external_access_restricted         = false

  enable_scaling_worker-ops          = false
  enable_scaling_worker-srm          = false

  shared_basicinfra                  = true
  rds_count                          = 0

  application_host_headers = {
    "CHECK"      = "${ENV_NAME}.aerius.nl",
    "CONNECT"    = "${ENV_NAME}.aerius.nl",
    "CALCULATOR" = "${ENV_NAME}.aerius.nl",
    "OPENDATA"   = "${ENV_NAME}.aerius.nl",
  }

  acm_certificate_domain      = "*.aerius.nl"
EOF

# If there is a product specific dynamic configuration, run it and add it environment.terragrunt.hcl
PRODUCT_SPECIFIC_DYNAMIC_SCRIPT="${ENV_NAME}/scripts/generate_local_properties.sh"
if [[ -x "${PRODUCT_SPECIFIC_DYNAMIC_SCRIPT}" ]]; then
  ./"${PRODUCT_SPECIFIC_DYNAMIC_SCRIPT}" >> "${ENV_ROOT_DIR}/environment.terragrunt.hcl"
fi

# Write end of environment.terragrunt.hcl
cat << EOF >> "${ENV_ROOT_DIR}/environment.terragrunt.hcl"
}
EOF
