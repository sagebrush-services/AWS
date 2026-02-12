#!/bin/bash

echo "=== Production Account (978489150794) ==="
creds=$(aws sts assume-role --role-arn "arn:aws:iam::978489150794:role/OrganizationAccountAccessRole" --role-session-name "get-stacks" --output json)
export AWS_ACCESS_KEY_ID=$(echo $creds | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $creds | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $creds | jq -r '.Credentials.SessionToken')
export AWS_ENDPOINT_URL=http://localhost.localstack.cloud:4566

for stack in prod-lambda-artifacts prod-user-uploads prod-application-logs prod-mailroom prod-email; do
  echo "Stack: $stack"
  aws cloudformation describe-stacks --stack-name $stack --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' --output text 2>/dev/null || echo "  (stack not found)"
done

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
echo ""
echo "=== Staging Account (889786867297) ==="
creds=$(aws sts assume-role --role-arn "arn:aws:iam::889786867297:role/OrganizationAccountAccessRole" --role-session-name "get-stacks" --output json)
export AWS_ACCESS_KEY_ID=$(echo $creds | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $creds | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $creds | jq -r '.Credentials.SessionToken')

for stack in staging-lambda-artifacts staging-user-uploads staging-application-logs staging-mailroom staging-email; do
  echo "Stack: $stack"
  aws cloudformation describe-stacks --stack-name $stack --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' --output text 2>/dev/null || echo "  (stack not found)"
done

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
echo ""
echo "=== Housekeeping Account (374073887345) ==="
creds=$(aws sts assume-role --role-arn "arn:aws:iam::374073887345:role/OrganizationAccountAccessRole" --role-session-name "get-stacks" --output json)
export AWS_ACCESS_KEY_ID=$(echo $creds | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $creds | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $creds | jq -r '.Credentials.SessionToken')

for stack in housekeeping-lambda-code housekeeping-billing-reports housekeeping-archive; do
  echo "Stack: $stack"
  aws cloudformation describe-stacks --stack-name $stack --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' --output text 2>/dev/null || echo "  (stack not found)"
done

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
echo ""
echo "=== NeonLaw Account (102186460229) ==="
creds=$(aws sts assume-role --role-arn "arn:aws:iam::102186460229:role/OrganizationAccountAccessRole" --role-session-name "get-stacks" --output json)
export AWS_ACCESS_KEY_ID=$(echo $creds | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $creds | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $creds | jq -r '.Credentials.SessionToken')

for stack in neonlaw-lambda-artifacts neonlaw-user-uploads neonlaw-application-logs neonlaw-email; do
  echo "Stack: $stack"
  aws cloudformation describe-stacks --stack-name $stack --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' --output text 2>/dev/null || echo "  (stack not found)"
done
