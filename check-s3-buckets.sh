#!/bin/bash

# Check S3 buckets across all accounts

echo "=== Production Account (978489150794) ==="
aws s3 ls --profile default \
  $(aws sts assume-role \
    --role-arn "arn:aws:iam::978489150794:role/OrganizationAccountAccessRole" \
    --role-session-name "check-buckets" \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text | \
    awk '{print "--profile default --region us-west-2"}') 2>&1 || \
  AWS_ACCESS_KEY_ID=$(aws sts assume-role --role-arn "arn:aws:iam::978489150794:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.AccessKeyId' --output text) \
  AWS_SECRET_ACCESS_KEY=$(aws sts assume-role --role-arn "arn:aws:iam::978489150794:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.SecretAccessKey' --output text) \
  AWS_SESSION_TOKEN=$(aws sts assume-role --role-arn "arn:aws:iam::978489150794:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.SessionToken' --output text) \
  aws s3 ls

echo ""
echo "Checking standards-lambda-artifacts-978489150794..."
AWS_ACCESS_KEY_ID=$(aws sts assume-role --role-arn "arn:aws:iam::978489150794:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.AccessKeyId' --output text) \
AWS_SECRET_ACCESS_KEY=$(aws sts assume-role --role-arn "arn:aws:iam::978489150794:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.SecretAccessKey' --output text) \
AWS_SESSION_TOKEN=$(aws sts assume-role --role-arn "arn:aws:iam::978489150794:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.SessionToken' --output text) \
aws s3 ls s3://standards-lambda-artifacts-978489150794 --recursive --summarize

echo ""
echo "=== Staging Account (889786867297) ==="
AWS_ACCESS_KEY_ID=$(aws sts assume-role --role-arn "arn:aws:iam::889786867297:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.AccessKeyId' --output text) \
AWS_SECRET_ACCESS_KEY=$(aws sts assume-role --role-arn "arn:aws:iam::889786867297:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.SecretAccessKey' --output text) \
AWS_SESSION_TOKEN=$(aws sts assume-role --role-arn "arn:aws:iam::889786867297:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.SessionToken' --output text) \
aws s3 ls

echo ""
echo "Checking standards-lambda-artifacts-889786867297..."
AWS_ACCESS_KEY_ID=$(aws sts assume-role --role-arn "arn:aws:iam::889786867297:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.AccessKeyId' --output text) \
AWS_SECRET_ACCESS_KEY=$(aws sts assume-role --role-arn "arn:aws:iam::889786867297:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.SecretAccessKey' --output text) \
AWS_SESSION_TOKEN=$(aws sts assume-role --role-arn "arn:aws:iam::889786867297:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.SessionToken' --output text) \
aws s3 ls s3://standards-lambda-artifacts-889786867297 --recursive --summarize

echo ""
echo "=== Housekeeping Account (374073887345) ==="
AWS_ACCESS_KEY_ID=$(aws sts assume-role --role-arn "arn:aws:iam::374073887345:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.AccessKeyId' --output text) \
AWS_SECRET_ACCESS_KEY=$(aws sts assume-role --role-arn "arn:aws:iam::374073887345:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.SecretAccessKey' --output text) \
AWS_SESSION_TOKEN=$(aws sts assume-role --role-arn "arn:aws:iam::374073887345:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.SessionToken' --output text) \
aws s3 ls

echo ""
echo "Checking housekeeping buckets..."
for bucket in "housekeeping-lambda-bucket" "sagebrush-housekeeping-lambda-code"; do
  echo "Bucket: $bucket"
  AWS_ACCESS_KEY_ID=$(aws sts assume-role --role-arn "arn:aws:iam::374073887345:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.AccessKeyId' --output text) \
  AWS_SECRET_ACCESS_KEY=$(aws sts assume-role --role-arn "arn:aws:iam::374073887345:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.SecretAccessKey' --output text) \
  AWS_SESSION_TOKEN=$(aws sts assume-role --role-arn "arn:aws:iam::374073887345:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.SessionToken' --output text) \
  aws s3 ls s3://$bucket --recursive --summarize
done

echo ""
echo "=== NeonLaw Account (102186460229) ==="
AWS_ACCESS_KEY_ID=$(aws sts assume-role --role-arn "arn:aws:iam::102186460229:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.AccessKeyId' --output text) \
AWS_SECRET_ACCESS_KEY=$(aws sts assume-role --role-arn "arn:aws:iam::102186460229:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.SecretAccessKey' --output text) \
AWS_SESSION_TOKEN=$(aws sts assume-role --role-arn "arn:aws:iam::102186460229:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.SessionToken' --output text) \
aws s3 ls

echo ""
echo "Checking standards-lambda-artifacts-102186460229..."
AWS_ACCESS_KEY_ID=$(aws sts assume-role --role-arn "arn:aws:iam::102186460229:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.AccessKeyId' --output text) \
AWS_SECRET_ACCESS_KEY=$(aws sts assume-role --role-arn "arn:aws:iam::102186460229:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.SecretAccessKey' --output text) \
AWS_SESSION_TOKEN=$(aws sts assume-role --role-arn "arn:aws:iam::102186460229:role/OrganizationAccountAccessRole" --role-session-name "check-buckets" --query 'Credentials.SessionToken' --output text) \
aws s3 ls s3://standards-lambda-artifacts-102186460229 --recursive --summarize
