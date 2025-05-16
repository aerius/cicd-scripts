#!/usr/bin/env bash

RESULT=''
for FLAG in $(echo "${FLAGS}" | tr ',' '\n'); do
  if [[ "${FLAG}" == 'TEST_'* ]]; then
    RESULT+=",${FLAG#TEST_}"
  fi
done

echo "${RESULT#,}"
