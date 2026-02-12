#!/bin/bash

echo "=== Production Account (978489150794) ==="
creds=$(aws sts assume-role --role-arn "arn:aws:iam::978489150794:role/OrganizationAccountAccessRole" --role-session-name "list-buckets" --output json)
AWS_ACCESS_KEY_ID=$(echo $creds | jq -r '.Credentials.AccessKeyId') \
AWS_SECRET_ACCESS_KEY=$(echo $creds | jq -r '.Credentials.SecretAccessKey') \
AWS_SESSION_TOKEN=$(echo $creds | jq -r '.Credentials.SessionToken') \
AWS_ENDPOINT_URL=http://localhost.localstack.cloud:4566 \
aws s3 ls | grep sagebrush

echo ""
echo "=== Staging Account (889786867297) ==="
creds=$(aws sts assume-role --role-arn "arn:aws:iam::889786867297:role/OrganizationAccountAccessRole" --role-session-name "list-buckets" --output json)
AWS_ACCESS_KEY_ID=$(echo $creds | jq -r '.Credentials.AccessKeyId') \
AWS_SECRET_ACCESS_KEY=$(echo $creds | jq -r '.Credentials.SecretAccessKey') \
AWS_SESSION_TOKEN=$(echo $creds | jq -r '.Credentials.SessionToken') \
AWS_ENDPOINT_URL=http://localhost.localstack.cloud:4566 \
aws s3 ls | grep sagebrush

echo ""
echo "=== Housekeeping Account (374073887345) ==="
creds=$(aws sts assume-role --role-arn "arn:aws:iam::374073887345:role/OrganizationAccountAccessRole" --role-session-name "list-buckets" --output json)
AWS_ACCESS_KEY_ID=$(echo $creds | jq -r '.Credentials.AccessKeyId') \
AWS_SECRET_ACCESS_KEY=$(echo $creds | jq -r '.Credentials.SecretAccessKey') \
AWS_SESSION_TOKEN=$(echo $creds | jq -r '.Credentials.SessionToken') \
AWS_ENDPOINT_URL=http://localhost.localstack.cloud:4566 \
aws s3 ls | grep sagebrush

echo ""
echo "=== NeonLaw Account (102186460229) ==="
creds=$(aws sts assume-role --role-arn "arn:aws:iam::102186460229:role/OrganizationAccountAccessRole" --role-session-name "list-buckets" --output json)
AWS_ACCESS_KEY_ID=$(echo $creds | jq -r '.Credentials.AccessKeyId') \
AWS_SECRET_ACCESS_KEY=$(echo $creds | jq -r '.Credentials.SecretAccessKey') \
AWS_SESSION_TOKEN=$(echo $creds | jq -r '.Credentials.SessionToken') \
AWS_ENDPOINT_URL=http://localhost.localstack.cloud:4566 \
aws s3 ls | grep sagebrush
