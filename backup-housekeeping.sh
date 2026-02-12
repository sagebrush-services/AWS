#!/bin/bash

cd ~/Trifecta/Sagebrush/AWS/s3-backup

echo "Getting temporary credentials for Housekeeping account..."
creds=$(aws sts assume-role \
  --role-arn "arn:aws:iam::374073887345:role/OrganizationAccountAccessRole" \
  --role-session-name "backup-s3" \
  --output json)

export AWS_ACCESS_KEY_ID=$(echo $creds | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $creds | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $creds | jq -r '.Credentials.SessionToken')

echo "Backing up sagebrush-housekeeping-lambda-code..."
aws s3 sync s3://sagebrush-housekeeping-lambda-code ./sagebrush-housekeeping-lambda-code

echo "Backup complete!"
ls -lh ./sagebrush-housekeeping-lambda-code
