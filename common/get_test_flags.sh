#!/usr/bin/env bash

RESULT=''
for FLAG in $(echo "${FLAGS}" | tr ',' '\n'); do
  if [[ "${FLAG}" == 'TEST_'* ]]; then
    RESULT+=",${FLAG}"
  fi
done

echo "${RESULT#,}"
