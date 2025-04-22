#!/usr/bin/env bash

# Exit on error
set -e

: ${1?'Missing argument containing job message'}

[[ -n "${CICD_JOB_MESSAGES}" ]] && CICD_JOB_MESSAGES+=';'
CICD_JOB_MESSAGES+="message ${1//;/[semicolon]}"

echo -n "${CICD_JOB_MESSAGES}"
