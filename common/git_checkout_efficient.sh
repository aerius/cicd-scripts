#!/usr/bin/env bash

# Exit on error
set -e

# Check whether the required vars are set
: ${1?'First argument missing - should be the directory to checkout in'}
: ${2?'Second argument missing - should be the repository URL to checkout'}
: ${3?'Third argument missing - should be the git commit/branch/tag to checkout'}

SPARSE_CHECKOUT_REQUESTED=false
[[ -n "${4}" ]] && SPARSE_CHECKOUT_REQUESTED=true
GIT_DIR="${1}"
GIT_URL="${2}"
GIT_CHECKOUT_COMMITISH="${3}"

# Process flags specified
echo "# Checking out '${2}' (${3}) in directory: ${1}"
[[ "${SPARSE_CHECKOUT_REQUESTED}" == 'true' ]] && echo "# Sparse checkout using path(s): ${@:4}" || true
# Checkout QA source repository efficiently
git init --initial-branch=main "${GIT_DIR}"
[[ "${SPARSE_CHECKOUT_REQUESTED}" == 'true' ]] && git --work-tree="${GIT_DIR}" --git-dir="${GIT_DIR}"/.git/ sparse-checkout set --no-cone || true
git --work-tree="${GIT_DIR}" --git-dir="${GIT_DIR}"/.git/ remote add origin "${GIT_URL}"
git --work-tree="${GIT_DIR}" --git-dir="${GIT_DIR}"/.git/ fetch --filter=blob:none --depth 1 origin "${GIT_CHECKOUT_COMMITISH}"
git --work-tree="${GIT_DIR}" --git-dir="${GIT_DIR}"/.git/ switch --detach FETCH_HEAD
[[ "${SPARSE_CHECKOUT_REQUESTED}" == 'true' ]] && git --work-tree="${GIT_DIR}" --git-dir="${GIT_DIR}"/.git/ sparse-checkout set --no-cone "${@:4}" || true
