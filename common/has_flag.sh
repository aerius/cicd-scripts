#!/usr/bin/env bash

for FLAG in $(echo "${FLAGS}" | tr ',' '\n'); do
  if [[ "${FLAG}" == "${1}" ]]; then
    exit 0
  fi
done

exit 1
