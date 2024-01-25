#!/usr/bin/env bash

# Exit on error
set -e

: ${1?'Missing argument containing current job result'}

case ${1} in
  SUCCESS)
    echo -n 'good'
    ;;
  FAILURE)
    echo -n 'danger'
    ;;
  *)
    echo -n 'warning'
    ;;
esac
