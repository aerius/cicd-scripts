#!/usr/bin/env bash

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

# Check whether the required DOCKER_IMAGE_POLICY_FILE is set
: ${DOCKER_IMAGE_POLICY_FILE?'DOCKER_IMAGE_POLICY_FILE is required for this script to function'}

# Per Docker image being pushed to the registry do some magic
while read DOCKER_IMAGE_NAME; do
  echo "[docker/prescript] # Found image to be pushed: ${DOCKER_IMAGE_NAME}"
  echo '[docker/prescript] # Creating Docker repository (this will fail if it already exists - which is fine)'
  aws ecr create-repository --repository-name "${AERIUS_REGISTRY_PATH}/${DOCKER_IMAGE_NAME}" || true
  echo '[docker/prescript] # Setting permissions on repository'
  aws ecr set-repository-policy --repository-name "${AERIUS_REGISTRY_PATH}/${DOCKER_IMAGE_NAME}" --policy-text file://"${DOCKER_IMAGE_POLICY_FILE}" || true
done < <(yq -r '.services[] | select( .image | contains("AERIUS_REGISTRY_URL") ) | .image | capture(".+AERIUS_REGISTRY_URL}(?<image>.+):.+") | .image' "${DOCKER_COMPOSE_FILE}" | sort | uniq)
