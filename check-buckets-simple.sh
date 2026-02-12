#!/bin/bash

check_bucket() {
  local account_id=$1
  local bucket_name=$2

  echo "Checking $bucket_name in account $account_id..."

  # Get temporary credentials
  creds=$(aws sts assume-role \
    --role-arn "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" \
    --role-session-name "check-buckets" \
    --output json)

  # Extract credentials
  export AWS_ACCESS_KEY_ID=$(echo $creds | jq -r '.Credentials.AccessKeyId')
  export AWS_SECRET_ACCESS_KEY=$(echo $creds | jq -r '.Credentials.SecretAccessKey')
  export AWS_SESSION_TOKEN=$(echo $creds | jq -r '.Credentials.SessionToken')

  # Check if bucket exists and list contents
  if aws s3 ls "s3://${bucket_name}" >/dev/null 2>&1; then
    aws s3 ls "s3://${bucket_name}" --recursive --summarize
  else
    echo "Bucket does not exist or access denied"
  fi

  # Unset credentials
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
  echo ""
}

echo "=== Production Account (978489150794) ==="
check_bucket "978489150794" "standards-lambda-artifacts-978489150794"

echo "=== Staging Account (889786867297) ==="
check_bucket "889786867297" "standards-lambda-artifacts-889786867297"

echo "=== Housekeeping Account (374073887345) ==="
check_bucket "374073887345" "housekeeping-lambda-bucket"
check_bucket "374073887345" "sagebrush-housekeeping-lambda-code"

echo "=== NeonLaw Account (102186460229) ==="
check_bucket "102186460229" "standards-lambda-artifacts-102186460229"
