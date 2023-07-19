#!/usr/bin/env bash

# Exit on error
set -e

# Record directory of script for convenience
SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

# Prepare stuff
source "${SCRIPT_DIR}"/../prepare/make_it_so.envsh

# Check whether the required vars are set
: ${SOURCE_JOB_NAME?'SOURCE_JOB_NAME is required for this script to function'}
: ${SOURCE_JOB_BUILD_NUMBER?'SOURCE_JOB_BUILD_NUMBER is required for this script to function'}
: ${DEPLOY_GIT_COMMIT?'DEPLOY_GIT_COMMIT is required for this script to function'}
: ${DEPLOY_GIT_URL?'DEPLOY_GIT_URL is required for this script to function'}
: ${AERIUS_REGISTRY_URL?'AERIUS_REGISTRY_URL is required for this script to function'}
: ${DEPLOY_IMAGE_TAG?'DEPLOY_IMAGE_TAG is required for the script to function'}
: ${SERVICE_TYPE?'SERVICE_TYPE is required for this script to function'}
# SERVICE_THEME is optional, so we do not check on it
: ${AWS_ACCOUNT_NAME?'AWS_ACCOUNT_NAME is required for this script to function'}
: ${DEPLOY_TERRAFORM_ACTION:=apply}

echo "[terraform/run] # Going to do a terraform build for: ${SOURCE_JOB_NAME} #${SOURCE_JOB_BUILD_NUMBER}"

cd "${WORKSPACE}"

ENV_NAME_UPPERCASE="${SOURCE_JOB_NAME}"
ENV_NAME="${SOURCE_JOB_NAME,,}"

# Generate a short environment name
# matches: *[year]*
if [[ "${ENV_NAME_UPPERCASE}" =~ [0-9]{4} ]]; then
  ENV_NAME_SHORT=$(echo "${ENV_NAME_UPPERCASE}" | sed -E 's#(.{3}).*([0-9]{4}.*)#\1\2#') # CALCULATOR1970-DEV becomes CAL1970-DEV
# For PR's we'll do something else
# matches: *-PR
elif [[ "${ENV_NAME_UPPERCASE}" == *-PR ]]; then
  ENV_NAME_SHORT=$(echo "${ENV_NAME_UPPERCASE}" | sed -E 's#(.{3}).*(-.*)#\1#')"-PR${SOURCE_JOB_BUILD_NUMBER}" # AERIUS-II-PR (with build number 119) becomes AER-PR119
# Fallback
else
  ENV_NAME_SHORT=$(echo "${ENV_NAME_UPPERCASE}" | sed -E 's#(.{3}).*(-.*)#\1\2#') # CALCULATOR-DEV becomes CAL-DEV
fi
# Let's make an exception if it's PRERELEASE, we should shorten that part as well
[[ "${ENV_NAME_SHORT}" == *-PRERELEASE ]] && ENV_NAME_SHORT="${ENV_NAME_SHORT//-PRERELEASE}-PRE"

DEPLOY_WEBHOST_SUBDOMAIN="${ENV_NAME}"
DEPLOY_WEBHOST_DOMAIN='aerius'
DEPLOY_WEBHOST_TLD='nl'

# If PR deploy, naming convention is a bit different
[[ "${ENV_NAME_UPPERCASE}" == *-PR ]] && \
  # AERIUS-II-PR (with buid number 119) becomes AERIUS-II-119
  DEPLOY_WEBHOST_SUBDOMAIN="${ENV_NAME%%-pr}-${SOURCE_JOB_BUILD_NUMBER}" \
  DEPLOY_WEBHOST_DOMAIN='pr.aerius' \
  ENV_NAME="${ENV_NAME}${SOURCE_JOB_BUILD_NUMBER}" \
  ENV_NAME_UPPERCASE="${ENV_NAME_UPPERCASE}${SOURCE_JOB_BUILD_NUMBER}"

# Determine AWS region to deploy for based on AWS_ACCOUNT_NAME - defaults to eu-west-1
# Also determine cognito settings and update TLD to use
AWS_REGION=eu-west-1
COGNITO_USER_POOL_NAME=nl-dev-aerius
[[ "${AWS_ACCOUNT_NAME}" == UK-* ]] \
  && AWS_REGION=eu-west-2 \
  && DEPLOY_WEBHOST_TLD='uk' \
  && COGNITO_USER_POOL_NAME=uk-dev-aerius
DEPLOY_WEBHOST="${DEPLOY_WEBHOST_SUBDOMAIN}.${DEPLOY_WEBHOST_DOMAIN}.${DEPLOY_WEBHOST_TLD}"
COGNITO_CALLBACK_DOMAIN="${DEPLOY_WEBHOST}"

# Set some convenience variables
ENV_ROOT_DIR="environments/${ENV_NAME}"
ECR_REPO=$(cut -d '/' -f1 <<<"${AERIUS_REGISTRY_URL}")
ECR_DIRECTORY=$(cut -d '/' -f2 <<<"${AERIUS_REGISTRY_URL}")

if [[ -d "${ENV_ROOT_DIR}" ]]; then
  echo '[terraform/run] # Environment directory "'"${ENV_ROOT_DIR}"'" already exists, quitting..'
  exit 1
fi

# Create environment root dir + region dir
mkdir -p "${ENV_ROOT_DIR}/${AWS_REGION}"

# Write modules.json
cat << EOF > "${ENV_ROOT_DIR}/modules.json"
[
  {
    "url": "${DEPLOY_GIT_URL}",
    "version": "${DEPLOY_GIT_COMMIT}",
    "checkout_path": "terraform"
  }
]
EOF

# Get environment modules
TERRAFORM_ENVIRONMENT="${ENV_NAME}" \
AWS_REGION="${AWS_REGION}" \
  scripts/prepare-modules.sh

# Write region.terragrunt.hcl - for now all our regions contains 3 AZ's, so this assumption is safe - let's automatically fetch it in the future
cat << EOF > "${ENV_ROOT_DIR}/region.terragrunt.hcl"
locals {
    aws_region         = "${AWS_REGION}"
    availability_zones = ["${AWS_REGION}a", "${AWS_REGION}b", "${AWS_REGION}c"]
}
EOF

# Get AWS account ID
AWS_ACCOUNT_ID=$(scripts/aws-account-name-to-id.sh "${AWS_ACCOUNT_NAME}")

# Write account.terragrunt.hcl
cat << EOF > "${ENV_ROOT_DIR}/account.terragrunt.hcl"
locals {
  account_id        = "${AWS_ACCOUNT_ID}"
}
EOF

# Write start of environment.terragrunt.hcl
cat << EOF > "${ENV_ROOT_DIR}/environment.terragrunt.hcl"
locals {
  service = {
    "code"  = "${ENV_NAME_UPPERCASE}"
    "type"  = "${SERVICE_TYPE}"
    "theme" = "${SERVICE_THEME}"
  }
  environment             = "${ENV_NAME_UPPERCASE}"
  environment_short       = "${ENV_NAME_SHORT}"

  tf_bucket_key_prefix    = "environments/${ENV_NAME}/"
  app_version             = "${DEPLOY_IMAGE_TAG}"

  ecr_repo                = "${ECR_REPO}"
  ecr_directory           = "${ECR_DIRECTORY}"

  cognito_enabled         = true
  cognito_user_pool_name  = "${COGNITO_USER_POOL_NAME}"
  cognito_callback_domain = "${COGNITO_CALLBACK_DOMAIN}"

  shared_basicinfra       = true
  rds_count               = 0

EOF

# If there is a product specific dynamic configuration, run it and add it environment.terragrunt.hcl
PRODUCT_SPECIFIC_DYNAMIC_SCRIPT_DIR="${ENV_ROOT_DIR}/${AWS_REGION}/env.d"
if [[ -d "${PRODUCT_SPECIFIC_DYNAMIC_SCRIPT_DIR}" ]]; then
  # Loop over the scripts
  for PRODUCT_SPECIFIC_DYNAMIC_SCRIPT in ${PRODUCT_SPECIFIC_DYNAMIC_SCRIPT_DIR}/*.sh; do
    # If it's not executable, crash
    ! [[ -x "${PRODUCT_SPECIFIC_DYNAMIC_SCRIPT}" ]] \
      && echo '[terraform/run] # The product specific dynamic script found ('"${PRODUCT_SPECIFIC_DYNAMIC_SCRIPT}"') is not executable, crashing..' \
      && exit 1

    echo '[terraform/run] # Running product specific dynamic script: '"${PRODUCT_SPECIFIC_DYNAMIC_SCRIPT}"
    echo '# Adding entries for: '"${PRODUCT_SPECIFIC_DYNAMIC_SCRIPT}" >> "${ENV_ROOT_DIR}/environment.terragrunt.hcl"
    ENV_NAME="${ENV_NAME}" \
    DEPLOY_WEBHOST="${DEPLOY_WEBHOST}" \
      ./"${PRODUCT_SPECIFIC_DYNAMIC_SCRIPT}" >> "${ENV_ROOT_DIR}/environment.terragrunt.hcl"
  done
fi

# Write end of environment.terragrunt.hcl
cat << EOF >> "${ENV_ROOT_DIR}/environment.terragrunt.hcl"
}
EOF

echo '# Actual files generated'
cat "${ENV_ROOT_DIR}/modules.json"
echo
cat "${ENV_ROOT_DIR}/region.terragrunt.hcl"
echo
cat "${ENV_ROOT_DIR}/account.terragrunt.hcl"
echo
cat "${ENV_ROOT_DIR}/environment.terragrunt.hcl"

# Do the real terragrunt action
TERRAFORM_ENVIRONMENT="${ENV_NAME}" \
TERRAFORM_ACTION="${DEPLOY_TERRAFORM_ACTION}" \
TERRAFORM_COMPONENT=application_services \
  scripts/do-terragrunt-action.sh
