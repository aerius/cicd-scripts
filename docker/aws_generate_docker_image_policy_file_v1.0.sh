#!/usr/bin/env bash

# Exit on error
set -e

# Change current directory to directory of script so it can be called from everywhere
SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")
cd "${SCRIPT_DIR}"

# Check whether the required AWS_ACCOUNT_IDS is set
: ${AWS_ACCOUNT_IDS?'AWS_ACCOUNT_IDS is required for this script to function'}

DOCKER_IMAGE_POLICY_FILE=aws_generate_docker_image_policy_file.json
cat << EOF > "${DOCKER_IMAGE_POLICY_FILE}"
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "AllowPull",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
EOF

read -a AWS_ACCOUNT_ID_ARR <<< "${AWS_ACCOUNT_IDS}"
for (( i = 0; i < ${#AWS_ACCOUNT_ID_ARR[@]}; i++ )); do
  echo -n '          "arn:aws:iam::'"${AWS_ACCOUNT_ID_ARR[$i]}"':root"' >> "${DOCKER_IMAGE_POLICY_FILE}"
  if (( i != ${#AWS_ACCOUNT_ID_ARR[@]} - 1 )); then
    echo -n ',' >> "${DOCKER_IMAGE_POLICY_FILE}"
  fi
  echo >> "${DOCKER_IMAGE_POLICY_FILE}"
done


cat << EOF >> "${DOCKER_IMAGE_POLICY_FILE}"
        ]
      },
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ]
    }
  ]
}
EOF
