#!/bin/bash

set -e

CLI="~/Trifecta/Sagebrush/AWS/.build/release/AWS"

echo "========================================="
echo "S3 Bucket Migration - UID-Based with Tags"
echo "========================================="
echo ""
echo "This script will:"
echo "1. Delete all existing S3 buckets"
echo "2. Create 17 new UID-based buckets with tags"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# Generate UUIDs for all buckets
echo ""
echo "Generating UUIDs for buckets..."

# Production (5 buckets)
PROD_LAMBDA_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
PROD_UPLOADS_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
PROD_LOGS_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
PROD_MAILROOM_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
PROD_EMAIL_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')

# Staging (5 buckets)
STAG_LAMBDA_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
STAG_UPLOADS_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
STAG_LOGS_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
STAG_MAILROOM_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
STAG_EMAIL_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')

# Housekeeping (3 buckets)
HOUSE_CODE_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
HOUSE_REPORTS_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
HOUSE_ARCHIVE_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')

# NeonLaw (4 buckets)
NEON_LAMBDA_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
NEON_UPLOADS_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
NEON_LOGS_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
NEON_EMAIL_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')

echo "✅ UUIDs generated"

# Step 1: Delete existing buckets
echo ""
echo "========================================="
echo "Step 1: Deleting existing S3 buckets"
echo "========================================="

# Management account buckets (delete all 3)
echo "🗑️  Deleting Management account buckets..."
aws s3 rb s3://sagebrush-public --force 2>/dev/null || echo "  sagebrush-public already deleted or doesn't exist"
aws s3 rb s3://sagebrush-private --force 2>/dev/null || echo "  sagebrush-private already deleted or doesn't exist"
aws s3 rb s3://sagebrush-mailroom-development --force 2>/dev/null || echo "  sagebrush-mailroom-development already deleted or doesn't exist"

# Production account
echo "🗑️  Deleting Production account buckets..."
creds=$(aws sts assume-role --role-arn "arn:aws:iam::978489150794:role/OrganizationAccountAccessRole" --role-session-name "delete-buckets" --output json)
AWS_ACCESS_KEY_ID=$(echo $creds | jq -r '.Credentials.AccessKeyId') \
AWS_SECRET_ACCESS_KEY=$(echo $creds | jq -r '.Credentials.SecretAccessKey') \
AWS_SESSION_TOKEN=$(echo $creds | jq -r '.Credentials.SessionToken') \
aws s3 rb s3://standards-lambda-artifacts-978489150794 --force 2>/dev/null || echo "  already deleted"

# Staging account
echo "🗑️  Deleting Staging account buckets..."
creds=$(aws sts assume-role --role-arn "arn:aws:iam::889786867297:role/OrganizationAccountAccessRole" --role-session-name "delete-buckets" --output json)
AWS_ACCESS_KEY_ID=$(echo $creds | jq -r '.Credentials.AccessKeyId') \
AWS_SECRET_ACCESS_KEY=$(echo $creds | jq -r '.Credentials.SecretAccessKey') \
AWS_SESSION_TOKEN=$(echo $creds | jq -r '.Credentials.SessionToken') \
aws s3 rb s3://standards-lambda-artifacts-889786867297 --force 2>/dev/null || echo "  already deleted"

# Housekeeping account
echo "🗑️  Deleting Housekeeping account buckets..."
creds=$(aws sts assume-role --role-arn "arn:aws:iam::374073887345:role/OrganizationAccountAccessRole" --role-session-name "delete-buckets" --output json)
AWS_ACCESS_KEY_ID=$(echo $creds | jq -r '.Credentials.AccessKeyId') \
AWS_SECRET_ACCESS_KEY=$(echo $creds | jq -r '.Credentials.SecretAccessKey') \
AWS_SESSION_TOKEN=$(echo $creds | jq -r '.Credentials.SessionToken') \
aws s3 rb s3://sagebrush-housekeeping-lambda-code --force 2>/dev/null || echo "  already deleted"

# NeonLaw account
echo "🗑️  Deleting NeonLaw account buckets..."
creds=$(aws sts assume-role --role-arn "arn:aws:iam::102186460229:role/OrganizationAccountAccessRole" --role-session-name "delete-buckets" --output json)
AWS_ACCESS_KEY_ID=$(echo $creds | jq -r '.Credentials.AccessKeyId') \
AWS_SECRET_ACCESS_KEY=$(echo $creds | jq -r '.Credentials.SecretAccessKey') \
AWS_SESSION_TOKEN=$(echo $creds | jq -r '.Credentials.SessionToken') \
aws s3 rb s3://standards-lambda-artifacts-102186460229 --force 2>/dev/null || echo "  already deleted"

echo "✅ All existing buckets deleted"

# Step 2: Create new tagged buckets
echo ""
echo "========================================="
echo "Step 2: Creating 17 new tagged S3 buckets"
echo "========================================="

# Production Account (5 buckets)
echo ""
echo "📦 Production Account (978489150794) - 5 buckets"

$CLI create-tagged-s3 --account 978489150794 --stack-name prod-lambda-artifacts --unique-id "$PROD_LAMBDA_UUID" \
  --logical-name "lambda-artifacts" \
  --purpose "Lambda deployment packages and build artifacts" \
  --environment "production" \
  --cost-center "Production" \
  --versioning

$CLI create-tagged-s3 --account 978489150794 --stack-name prod-user-uploads --unique-id "$PROD_UPLOADS_UUID" \
  --logical-name "user-uploads" \
  --purpose "Production user file uploads" \
  --environment "production" \
  --cost-center "Production"

$CLI create-tagged-s3 --account 978489150794 --stack-name prod-application-logs --unique-id "$PROD_LOGS_UUID" \
  --logical-name "application-logs" \
  --purpose "Application and Lambda logs" \
  --environment "production" \
  --cost-center "Production"

$CLI create-tagged-s3 --account 978489150794 --stack-name prod-mailroom --unique-id "$PROD_MAILROOM_UUID" \
  --logical-name "mailroom" \
  --purpose "Physical mail processing and virtual mailbox documents" \
  --environment "production" \
  --cost-center "Production"

$CLI create-tagged-s3 --account 978489150794 --stack-name prod-email --unique-id "$PROD_EMAIL_UUID" \
  --logical-name "email" \
  --purpose "Email processing and temporary message storage" \
  --environment "production" \
  --cost-center "Production"

# Staging Account (5 buckets)
echo ""
echo "📦 Staging Account (889786867297) - 5 buckets"

$CLI create-tagged-s3 --account 889786867297 --stack-name staging-lambda-artifacts --unique-id "$STAG_LAMBDA_UUID" \
  --logical-name "lambda-artifacts" \
  --purpose "Lambda deployment packages and build artifacts" \
  --environment "staging" \
  --cost-center "Staging" \
  --versioning

$CLI create-tagged-s3 --account 889786867297 --stack-name staging-user-uploads --unique-id "$STAG_UPLOADS_UUID" \
  --logical-name "user-uploads" \
  --purpose "Staging user file uploads for testing" \
  --environment "staging" \
  --cost-center "Staging"

$CLI create-tagged-s3 --account 889786867297 --stack-name staging-application-logs --unique-id "$STAG_LOGS_UUID" \
  --logical-name "application-logs" \
  --purpose "Application and Lambda logs" \
  --environment "staging" \
  --cost-center "Staging"

$CLI create-tagged-s3 --account 889786867297 --stack-name staging-mailroom --unique-id "$STAG_MAILROOM_UUID" \
  --logical-name "mailroom" \
  --purpose "Physical mail processing and virtual mailbox documents" \
  --environment "staging" \
  --cost-center "Staging"

$CLI create-tagged-s3 --account 889786867297 --stack-name staging-email --unique-id "$STAG_EMAIL_UUID" \
  --logical-name "email" \
  --purpose "Email processing and temporary message storage" \
  --environment "staging" \
  --cost-center "Staging"

# Housekeeping Account (3 buckets)
echo ""
echo "📦 Housekeeping Account (374073887345) - 3 buckets"

$CLI create-tagged-s3 --account 374073887345 --stack-name housekeeping-lambda-code --unique-id "$HOUSE_CODE_UUID" \
  --logical-name "lambda-code" \
  --purpose "DailyBilling and housekeeping Lambda functions" \
  --environment "housekeeping" \
  --cost-center "Housekeeping" \
  --versioning

$CLI create-tagged-s3 --account 374073887345 --stack-name housekeeping-billing-reports --unique-id "$HOUSE_REPORTS_UUID" \
  --logical-name "billing-reports" \
  --purpose "Daily billing reports and cost data exports" \
  --environment "housekeeping" \
  --cost-center "Housekeeping"

$CLI create-tagged-s3 --account 374073887345 --stack-name housekeeping-archive --unique-id "$HOUSE_ARCHIVE_UUID" \
  --logical-name "archive" \
  --purpose "Cross-account backups and disaster recovery" \
  --environment "housekeeping" \
  --cost-center "Housekeeping"

# NeonLaw Account (4 buckets)
echo ""
echo "📦 NeonLaw Account (102186460229) - 4 buckets"

$CLI create-tagged-s3 --account 102186460229 --stack-name neonlaw-lambda-artifacts --unique-id "$NEON_LAMBDA_UUID" \
  --logical-name "lambda-artifacts" \
  --purpose "Lambda deployment packages and build artifacts" \
  --environment "neonlaw" \
  --cost-center "NeonLaw" \
  --versioning

$CLI create-tagged-s3 --account 102186460229 --stack-name neonlaw-user-uploads --unique-id "$NEON_UPLOADS_UUID" \
  --logical-name "user-uploads" \
  --purpose "NeonLaw user file uploads" \
  --environment "neonlaw" \
  --cost-center "NeonLaw"

$CLI create-tagged-s3 --account 102186460229 --stack-name neonlaw-application-logs --unique-id "$NEON_LOGS_UUID" \
  --logical-name "application-logs" \
  --purpose "Application and Lambda logs" \
  --environment "neonlaw" \
  --cost-center "NeonLaw"

$CLI create-tagged-s3 --account 102186460229 --stack-name neonlaw-email --unique-id "$NEON_EMAIL_UUID" \
  --logical-name "email" \
  --purpose "Email processing and temporary message storage" \
  --environment "neonlaw" \
  --cost-center "NeonLaw"

echo ""
echo "========================================="
echo "✅ Migration Complete!"
echo "========================================="
echo ""
echo "Summary:"
echo "- Management: 0 buckets (all deleted)"
echo "- Production: 5 buckets"
echo "- Staging: 5 buckets"
echo "- Housekeeping: 3 buckets"
echo "- NeonLaw: 4 buckets"
echo ""
echo "Total: 17 buckets created with UID-based names and tags"
echo ""
echo "Next steps:"
echo "1. Restore backed up Lambda code to Housekeeping lambda-code bucket"
echo "2. Update DEPLOYED_RESOURCES.md"
echo "3. Update Lambda function environment variables"
