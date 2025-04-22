#!/usr/bin/env bash

# Exit on error
set -e

: ${1?'Missing argument containing duration type'}
: ${2?'Missing argument containing duration'}

DURATION_TYPE="${1}"
DURATION="${2%and counting}"

[[ -n "${CICD_JOB_MESSAGES}" ]] && CICD_JOB_MESSAGES+=';'
CICD_JOB_MESSAGES+="jobduration ${DURATION_TYPE} ${DURATION}"

echo -n "${CICD_JOB_MESSAGES}"
