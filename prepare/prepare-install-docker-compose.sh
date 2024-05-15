#!/usr/bin/env bash

# Exit on error
set -e

if ! [[ -x "${CICD_SCRIPTS_TOOLS_DIR}"/docker-compose ]]; then
  echo '[prepare] # Installing docker-compose'
  COMPOSE_IMAGE_ID=$(docker create "docker/compose-bin:${CICD_SCRIPTS_DOCKER_COMPOSE_VERSION}" sleep 1m)
  docker cp "${COMPOSE_IMAGE_ID}":/docker-compose "${CICD_SCRIPTS_TOOLS_DIR}"/docker-compose
  docker rm "${COMPOSE_IMAGE_ID}"
else
  echo '[prepare] # docker-compose is already installed, skipping install.'
fi

# Print version
"${CICD_SCRIPTS_TOOLS_DIR}"/docker-compose --version
echo

