#!/usr/bin/env bash

# Exit on error
set -e

# Tools needed for this script to function
export CICD_SCRIPTS_TOOL_YQ=true

# Record directory of script for convenience
SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

# Prepare stuff
source "${SCRIPT_DIR}"/../prepare/make_it_so.envsh

# We should only proceed at this time if we find an ECR URL
if [[ "${AERIUS_REGISTRY_URL}" != *.ecr.*.amazonaws.com/* ]]; then
  echo '[docker/prescript] # Did not find an ECR URL, skipping prescript'
  exit 0
fi

unset DOCKER_COMPOSE_FILE
# Determine docker compose file to read services from
if [[ -f docker-compose.yaml ]]; then
  DOCKER_COMPOSE_FILE=docker-compose.yaml
elif [[ -f generated/docker-compose-original.yaml ]]; then
  DOCKER_COMPOSE_FILE=generated/docker-compose-original.yaml
fi

# Check whether we found a suitable docker-compose.yaml
: ${DOCKER_COMPOSE_FILE?'No suitable docker-compose file found in the current directory: '"$(pwd)"}

# Check whether the required AERIUS_REGISTRY_PATH is set
: ${AERIUS_REGISTRY_PATH?'AERIUS_REGISTRY_PATH is required for this script to function'}

# The policy as applied to a OTA environment
REPOSITORY_LIFECYCLE_POLICY_TEXT='
{
   "rules": [
       {
           "rulePriority": 1,
           "description": "Only keep the last 5 images",
           "selection": {
               "tagStatus": "any",
               "countType": "imageCountMoreThan",
               "countNumber": 5
           },
           "action": {
               "type": "expire"
           }
       }
   ]
}
'

# Per Docker image being pushed to the registry do some magic
while read DOCKER_IMAGE_NAME; do
  echo "[docker/prescript] # Found image to be pushed: ${DOCKER_IMAGE_NAME}"
  echo '[docker/prescript] # Creating Docker repository (this will fail if it already exists - which is fine)'
  aws ecr create-repository --repository-name "${AERIUS_REGISTRY_PATH}/${DOCKER_IMAGE_NAME}" --image-tag-mutability IMMUTABLE || true
  echo '[docker/prescript] # Setting permissions on repository'
  aws ecr set-repository-policy --repository-name "${AERIUS_REGISTRY_PATH}/${DOCKER_IMAGE_NAME}" --policy-text file://"${SCRIPT_DIR}"/aws_generate_docker_image_policy_file.json
  # Only if repository matches known OTA-like names, set the policy (I'd rather have too many images than lose some by mistake)
  if [[ "${AERIUS_REGISTRY_PATH}" == ota/* ]] || [[ "${AERIUS_REGISTRY_PATH}" == temporary-custom/* ]]; then
    echo '[docker/prescript] # Setting lifecycle-policy on repository'
    aws ecr put-lifecycle-policy --repository-name "${AERIUS_REGISTRY_PATH}/${DOCKER_IMAGE_NAME}" --lifecycle-policy-text "${REPOSITORY_LIFECYCLE_POLICY_TEXT}"
  else
    echo '[docker/prescript] # WARNING: Skipping setting lifecycle-policy on repository as no OTA like path was detected'
  fi
done < <(
  "${CICD_SCRIPTS_TOOLS_DIR}"/yq -r '.services[] | select( .image | contains("AERIUS_REGISTRY_URL") ) | .image | capture(".+AERIUS_REGISTRY_URL}(?P<image>.+):.+") | .image' "${DOCKER_COMPOSE_FILE}" |
    sort |
    uniq)
