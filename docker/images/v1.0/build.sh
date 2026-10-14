#!/usr/bin/env bash

# Exit on error
set -e

# Record directory of script for convenience
SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

# include functions
source "${SCRIPT_DIR}"/functions.sh

# Set variables we will re-use multiple times
PROFILE_PATH="${GENERATED_DIRECTORY}/${CUSTOM_PROFILE_FILENAME}"
DOCKER_COMPOSE_ORIGINAL_PATH="${GENERATED_DIRECTORY}/docker-compose-original.yaml"

# Set variable with whether the custom profile file is found
[[ -f "${PROFILE_PATH}" ]] && PROFILE_PATH_FOUND=0 || PROFILE_PATH_FOUND=1

####################
### Validations ###
###################

# Check if a custom theme exists
if ! ( [[ -d "${GENERATED_DIRECTORY}" ]] || [[ -f "${DOCKER_COMPOSE_ORIGINAL_PATH}" ]] ); then
  _cicd_error 'Generated directory not found. Use the prepare script to generate one first.'
fi

# Read in profile if it exists
[[ "${PROFILE_PATH_FOUND}" == 0 ]] && source "${PROFILE_PATH}"

# Read in CICD config if it exists
_cicd_read_in_config

# If a database is being built HTTPS_DATA_USERNAME/PASSWORDS are required
if [[ "${CICD_CONFIG_USES_DATABASE_BUILD}" == 'true' ]] && [[ "${PROFILE_PATH_FOUND}" == 1 || "${SERVICES[*]}" == *database* ]]; then
  : ${HTTPS_DATA_USERNAME?'ENV variable HTTPS_DATA_USERNAME is required if a database needs to be built'}
  : ${HTTPS_DATA_PASSWORD?'ENV variable HTTPS_DATA_PASSWORD is required if a database needs to be built'}

  CICD_SUPPLY_HTTPS_DATA='true'
# Just overwriting it, because we don't know what people do in repositories..
# I mean nothing will blow up if they would set this.. but.. :shrug:
else
  CICD_SUPPLY_HTTPS_DATA='false'
fi

#####################
### The real deal ###
#####################

# Dump processed docker-compose.yaml
_cicd_log '# Dump processed docker-compose.yaml'
"${CICD_SCRIPTS_TOOLS_DIR}"/docker-compose -f "${DOCKER_COMPOSE_ORIGINAL_PATH}" --project-directory "${GENERATED_DIRECTORY}" config > "${DOCKER_COMPOSE_PATH}"
echo

cat "${DOCKER_COMPOSE_PATH}"

# Check if a service matching database* is present
grep -F -e '  database' "${DOCKER_COMPOSE_PATH}" | grep -e ':$' &>/dev/null && COMPOSE_CONTAINS_DB_SERVICE=true

# Build images
_cicd_log '# Building images'
CICD_BUILDX_BAKE_EXTRA_ARGS=()
[[ "${CICD_SUPPLY_HTTPS_DATA}" == 'true' ]] && [[ "${COMPOSE_CONTAINS_DB_SERVICE}" == 'true' ]] && CICD_BUILDX_BAKE_EXTRA_ARGS+=('--set' 'database*.args.HTTPS_DATA_USERNAME='"${HTTPS_DATA_USERNAME}" '--set' 'database*.args.HTTPS_DATA_PASSWORD='"${HTTPS_DATA_PASSWORD}")

# When pushing, build with a docker-container builder: the default docker builder pushes through the Docker daemon,
# which gzips every layer on a single core and ignores compression options
docker buildx inspect cicd-push &>/dev/null || docker buildx create --name cicd-push --driver docker-container
[[ "${1}" != '--no-push' && -n "${AERIUS_REGISTRY_URL}" ]] && CICD_BUILDX_BAKE_EXTRA_ARGS+=('--builder' 'cicd-push')

docker buildx bake -f "${DOCKER_COMPOSE_PATH}" ${CICD_BUILDX_BAKE_EXTRA_ARGS[@]} --print
docker buildx bake -f "${DOCKER_COMPOSE_PATH}" ${CICD_BUILDX_BAKE_EXTRA_ARGS[@]}

# Only push if --no-push isn't provided and a registry URL is set
if [[ "${1}" != '--no-push' && -n "${AERIUS_REGISTRY_URL}" ]]; then
  _cicd_log '# Pushing images'
  docker buildx bake -f "${DOCKER_COMPOSE_PATH}" ${CICD_BUILDX_BAKE_EXTRA_ARGS[@]} --set '*.output=type=registry,compression=zstd,compression-level=3,force-compression=true'
  _cicd_log '# Finished pushing images'

  _cicd_log '# Compressed size of the pushed images'
  for IMAGE in $("${CICD_SCRIPTS_TOOLS_DIR}"/yq '.services[] | select(has("build")) | .image' "${DOCKER_COMPOSE_PATH}"); do
    DIGEST=$(docker buildx imagetools inspect --raw "${IMAGE}" | "${CICD_SCRIPTS_TOOLS_DIR}"/yq -p json '.manifests[] | select(.platform.os != "unknown") | .digest' | head -1)
    SIZE_MB=$(docker buildx imagetools inspect --raw "${IMAGE}${DIGEST:+@${DIGEST}}" | "${CICD_SCRIPTS_TOOLS_DIR}"/yq -p json '.layers[].size' | awk '{ sum += $1 } END { print int(sum / 1000000) }')
    echo "${IMAGE}: ${SIZE_MB} MB"
  done
fi
