#!/usr/bin/env bash

# Ignore these files when we try to copy dependencies from base directories
IGNORED_DEPENDENCIES=(Dockerfile Dockerfile.template README.md)

# Exit on error
set -e

# function to process template.
# $1 = path to template
# $2 = directory to write Dockerfile + dependencies to
function process_template() {
  local TEMPLATE_PATH="${1}"
  local TEMPLATE_DIRECTORY="${2}"
  local OUTPUT_FILE="${2}"/Dockerfile

  echo '- Processing: '"${TEMPLATE_PATH}"
  # Read the Dockerfile template and process it line by line
  while IFS= read -r LINE; do
    # If base image string found, replace it with the contents of the base image
    if [[ "${LINE}" == '### BASE: '* ]]; then
      local BASE=${LINE##\#\#\# BASE: }

      echo '- Found base image: '"${BASE}"

      # Find matching base Dockerfile.template
      local BASE_DOCKERFILE=$(find . -wholename '*/'"${BASE}"'/Dockerfile.template')
      if [[ -z "${BASE_DOCKERFILE}" ]]; then
        # If not found try to find matching base Dockerfile
        BASE_DOCKERFILE=$(find . -wholename '*/'"${BASE}"'/Dockerfile')
        [[ -z "${BASE_DOCKERFILE}" ]] && _cicd_error 'Could not find base Dockerfile or template: '"${BASE}"
      fi

      # Copy over dependencies present in the base image directory if found
      for DEPENDENCY_PATH in $(dirname "${BASE_DOCKERFILE}")/*; do
        local DEPENDENCY_FILENAME=$(basename "${DEPENDENCY_PATH}")

        if [[ ! " ${IGNORED_DEPENDENCIES[@]} " =~ " ${DEPENDENCY_FILENAME} " ]]; then
          cp -auv "${DEPENDENCY_PATH}" "${TEMPLATE_DIRECTORY}"
        fi
      done

      echo '### BASE '"${BASE}"' IMAGE ###' >> "${OUTPUT_FILE}"
      process_template "${BASE_DOCKERFILE}" "${TEMPLATE_DIRECTORY}"
      echo '### END BASE '"${BASE}"' IMAGE ###' >> "${OUTPUT_FILE}"
    # Else simply print the line in the template
    else
      echo "${LINE}" >> "${OUTPUT_FILE}"
    fi
  done < <(cat "${TEMPLATE_PATH}")
}

# Find all template files and process them
while read TEMPLATE_PATH; do
  TEMPLATE_DIRECTORY=$(dirname "${TEMPLATE_PATH}")
  echo '# Found a template in: '"${TEMPLATE_DIRECTORY}"

  # Remove old generated Dockerfile if present
  if [[ -f "${TEMPLATE_DIRECTORY}"/Dockerfile ]]; then
    rm -v "${TEMPLATE_DIRECTORY}"/Dockerfile
  fi

  process_template "${TEMPLATE_PATH}" "${TEMPLATE_DIRECTORY}"
  echo
done < <(find . -name Dockerfile.template)

echo 'Templates processed!'
