# AWS Infrastructure Commands Reference

Quick reference for deploying infrastructure across all Sagebrush AWS accounts.

## Account Overview

- **Management** (731099197338): Organization management, billing, cross-account IAM
- **Production** (978489150794): Production workloads and services  
- **Staging** (889786867297): Pre-production testing environment
- **Housekeeping** (374073887345): Operational tooling and maintenance
- **NeonLaw** (102186460229): NeonLaw application infrastructure

## Prerequisites

```bash
# Set management account credentials (used for all accounts via AssumeRole)
export AWS_ACCESS_KEY_ID="your-management-account-access-key"
export AWS_SECRET_ACCESS_KEY="your-management-account-secret-key"
export AWS_DEFAULT_REGION="us-west-2"

# Build the CLI
cd ~/Trifecta/SagebrushServices/AWS
swift build -c release
```

## Management Account (731099197338)

### IAM & Access Control

```bash
# Deploy SagebrushCLIRole (one-time setup)
ENV=production swift run AWS create-iam --region us-west-2

# Deploy console access group
ENV=production swift run AWS create-console-access-group --region us-west-2 \
  --stack-name ConsoleAccessGroup --group-name CrossAccountAdministrators

# Create Service Control Policy for staging region restriction
ENV=production swift run AWS create-scp --region us-west-2 --stack-name StagingRegionRestriction \
  --policy-name "RestrictStagingRegions" --allowed-region1 us-west-2 --allowed-region2 us-east-1 \
  --target-account-id 889786867297
```

### Core Infrastructure  

```bash
# VPC (oregon-vpc)
ENV=production swift run AWS create-vpc --region us-west-2 --stack-name oregon-vpc --class-b 10

# RDS Aurora PostgreSQL (oregon-rds)
ENV=production swift run AWS create-aurora-postgres --region us-west-2 --stack-name oregon-rds \
  --vpc-stack oregon-vpc --db-name sagebrush --db-username postgres --min-capacity 0.5 --max-capacity 2

# S3 buckets
ENV=production swift run AWS create-s3 --region us-west-2 --stack-name sagebrush-public-bucket \
  --bucket-name sagebrush-public-bucket --public-access
ENV=production swift run AWS create-s3 --region us-west-2 --stack-name sagebrush-mailroom-bucket --bucket-name sagebrush-mailroom-bucket

# ALB (sagebrush-alb)
ENV=production swift run AWS create-alb --region us-west-2 --stack-name sagebrush-alb \
  --vpc-stack oregon-vpc --ecs-stack oregon-ecs --domain-name www.sagebrush.services
```

### DNS & Email (Route53 + SES)

Route53 hosted zones and email infrastructure are centrally managed in the management account.

```bash
# Step 1: Create Route53 hosted zone for sagebrush.services
ENV=production swift run AWS create-route53 \
  --region us-west-2 \
  --stack-name sagebrush-dns \
  --domain-name sagebrush.services

# Step 2: Create SES domain identity (in housekeeping account for email sending)
ENV=production swift run AWS create-ses \
  --account housekeeping \
  --region us-west-2 \
  --stack-name sagebrush-ses \
  --domain-name sagebrush.services \
  --email-address support@sagebrush.services

# Step 3: Get DKIM tokens from SES CloudFormation outputs
aws cloudformation describe-stacks \
  --region us-west-2 \
  --stack-name sagebrush-ses \
  --query 'Stacks[0].Outputs' \
  --profile housekeeping

# Step 4: Update Route53 with email records (MX, SPF, DMARC, DKIM)
ENV=production swift run AWS create-route53 \
  --region us-west-2 \
  --stack-name sagebrush-dns \
  --domain-name sagebrush.services \
  --mx-record "10 inbound-smtp.us-west-2.amazonaws.com" \
  --spf-record "v=spf1 include:amazonses.com ~all" \
  --dmarc-record "v=DMARC1; p=quarantine; rua=mailto:dmarc@sagebrush.services" \
  --dkim-token1 "<DKIMToken1-from-ses-output>" \
  --dkim-value1 "<DKIMValue1-from-ses-output>" \
  --dkim-token2 "<DKIMToken2-from-ses-output>" \
  --dkim-value2 "<DKIMValue2-from-ses-output>" \
  --dkim-token3 "<DKIMToken3-from-ses-output>" \
  --dkim-value3 "<DKIMValue3-from-ses-output>"

# Step 5: After deploying ALBs, add DNS records for web services
ENV=production swift run AWS create-route53 \
  --region us-west-2 \
  --stack-name sagebrush-dns \
  --domain-name sagebrush.services \
  --www-target "sagebrush-alb-1234567890.us-west-2.elb.amazonaws.com" \
  --staging-target "staging-alb-0987654321.us-west-2.elb.amazonaws.com"

# Verify DNS records
aws route53 list-resource-record-sets \
  --hosted-zone-id <hosted-zone-id-from-output> \
  --region us-west-2

# LocalStack testing (development)
# Start LocalStack
localstack start

# Create Route53 stack in LocalStack
swift run AWS create-route53 \
  --region us-east-1 \
  --stack-name sagebrush-dns \
  --domain-name sagebrush.services \
  --mx-record "10 inbound-smtp.us-east-1.amazonaws.com" \
  --spf-record "v=spf1 include:amazonses.com ~all" \
  --dmarc-record "v=DMARC1; p=quarantine; rua=mailto:dmarc@sagebrush.services" \
  --dkim-token1 "test1" \
  --dkim-value1 "test1.dkim.amazonses.com" \
  --dkim-token2 "test2" \
  --dkim-value2 "test2.dkim.amazonses.com" \
  --dkim-token3 "test3" \
  --dkim-value3 "test3.dkim.amazonses.com"

# Verify in LocalStack
aws --endpoint-url=http://localhost.localstack.cloud:4566 route53 list-resource-record-sets \
  --hosted-zone-id <hosted-zone-id> \
  --region us-east-1
```

## Production Account (978489150794)

### Initial Setup

```bash
# Deploy IAM role (one-time)
ENV=production swift run AWS create-iam --account 978489150794 --region us-west-2

# Deploy console access role
ENV=production swift run AWS create-console-access-role --account 978489150794 --region us-west-2 \
  --stack-name ConsoleAccessRole --role-name ConsoleAdminAccess --permission-level Administrator
```

### Infrastructure Stack

```bash
# VPC
ENV=production swift run AWS create-vpc --account 978489150794 --region us-west-2 \
  --stack-name prod-vpc --class-b 10

# ECS Cluster
ENV=production swift run AWS create-ecs --account 978489150794 --region us-west-2 \
  --stack-name prod-ecs --vpc-stack prod-vpc --cluster-name production-cluster

# RDS Aurora PostgreSQL
ENV=production swift run AWS create-aurora-postgres --account 978489150794 --region us-west-2 \
  --stack-name prod-rds --vpc-stack prod-vpc --db-name production --db-username postgres \
  --min-capacity 0.5 --max-capacity 4

# S3 Buckets
ENV=production swift run AWS create-s3 --account 978489150794 --region us-west-2 \
  --stack-name prod-public-bucket --bucket-name sagebrush-production-public-assets --public-access
ENV=production swift run AWS create-s3 --account 978489150794 --region us-west-2 \
  --stack-name prod-private-bucket --bucket-name sagebrush-production-private-uploads

# ALB
ENV=production swift run AWS create-alb --account 978489150794 --region us-west-2 \
  --stack-name prod-alb --vpc-stack prod-vpc --ecs-stack prod-ecs --domain-name www.sagebrush.services
```

## Staging Account (889786867297)

### Initial Setup

```bash
# Deploy IAM role (one-time)
ENV=production swift run AWS create-iam --account 889786867297 --region us-west-2

# Deploy console access role
ENV=production swift run AWS create-console-access-role --account 889786867297 --region us-west-2 \
  --stack-name ConsoleAccessRole --role-name ConsoleAdminAccess --permission-level Administrator

# Deploy budget ($100/month with 80% alert)
ENV=production swift run AWS create-budget --account 889786867297 --region us-west-2 \
  --stack-name StagingBudget --budget-name "Staging Monthly Budget" --budget-amount 100 \
  --email-address admin@example.com --threshold-percentage 80
```

### Infrastructure Stack

```bash
# VPC
ENV=production swift run AWS create-vpc --account 889786867297 --region us-west-2 \
  --stack-name staging-vpc --class-b 11

# ECS Cluster
ENV=production swift run AWS create-ecs --account 889786867297 --region us-west-2 \
  --stack-name staging-ecs --vpc-stack staging-vpc --cluster-name staging-cluster

# RDS Aurora PostgreSQL
ENV=production swift run AWS create-aurora-postgres --account 889786867297 --region us-west-2 \
  --stack-name staging-rds --vpc-stack staging-vpc --db-name staging --db-username postgres \
  --min-capacity 0.5 --max-capacity 2

# S3 Buckets
ENV=production swift run AWS create-s3 --account 889786867297 --region us-west-2 \
  --stack-name staging-public-bucket --bucket-name sagebrush-staging-public-assets --public-access
ENV=production swift run AWS create-s3 --account 889786867297 --region us-west-2 \
  --stack-name staging-private-bucket --bucket-name sagebrush-staging-private-uploads
```

## Housekeeping Account (374073887345)

### Initial Setup

```bash
# Deploy IAM role (one-time)
ENV=production swift run AWS create-iam --account 374073887345 --region us-west-2

# Deploy console access role
ENV=production swift run AWS create-console-access-role --account 374073887345 --region us-west-2 \
  --stack-name ConsoleAccessRole --role-name ConsoleAdminAccess --permission-level Administrator
```

### Infrastructure Stack

```bash
# VPC
ENV=production swift run AWS create-vpc --account 374073887345 --region us-west-2 \
  --stack-name housekeeping-vpc --class-b 12

# Lambda for automated maintenance
ENV=production swift run AWS create-lambda --account 374073887345 --region us-west-2 \
  --stack-name housekeeping-lambda --s3-stack housekeeping-bucket --function-name HousekeepingFunction
```

## NeonLaw Account (102186460229)

### Initial Setup

```bash
# Deploy IAM role (one-time)
ENV=production swift run AWS create-iam --account 102186460229 --region us-west-2

# Deploy console access role
ENV=production swift run AWS create-console-access-role --account 102186460229 --region us-west-2 \
  --stack-name ConsoleAccessRole --role-name ConsoleAdminAccess --permission-level Administrator

# Deploy GitHub OIDC for CI/CD
ENV=production swift run AWS create-github-oidc --account 102186460229 --region us-west-2 \
  --stack-name GitHubOIDC --github-org nicholasamiller --github-repo standards \
  --iam-role-name GitHubActionsRole
```

### Core Infrastructure

```bash
# VPC (oregon-vpc - legacy naming)
ENV=production swift run AWS create-vpc --account 102186460229 --region us-west-2 \
  --stack-name oregon-vpc --class-b 10

# Alternative VPC (neonlaw-vpc)
ENV=production swift run AWS create-vpc --account 102186460229 --region us-west-2 \
  --stack-name neonlaw-vpc --class-b 13

# RDS Aurora PostgreSQL with Secrets Manager
ENV=production swift run AWS create-aurora-postgres --account 102186460229 --region us-west-2 \
  --stack-name neonlaw-aurora-postgres --vpc-stack neonlaw-vpc --db-name neonlaw \
  --db-username postgres --min-capacity 0.5 --max-capacity 2
```

### CodeCommit Repositories

```bash
# GreenCrossFarmacy repository
ENV=production swift run AWS create-codecommit --account 102186460229 --region us-west-2 \
  --stack-name GreenCrossFarmacy --repository-name GreenCrossFarmacy

# Standards repository
ENV=production swift run AWS create-codecommit --account 102186460229 --region us-west-2 \
  --stack-name Standards --repository-name Standards

# NLF (Neon Law Foundation) repository
ENV=production swift run AWS create-codecommit --account 102186460229 --region us-west-2 \
  --stack-name NLF --repository-name NLF
```

### Build & Deployment

```bash
# S3 bucket for Lambda artifacts
ENV=production swift run AWS create-s3 --account 102186460229 --region us-west-2 \
  --stack-name standards-lambda-artifacts --bucket-name standards-lambda-artifacts

# CodeBuild for Swift Lambda ARM64
ENV=production swift run AWS create-codebuild --account 102186460229 --region us-west-2 \
  --stack-name standards-codebuild --s3-stack standards-lambda-artifacts \
  --project-name standards-build --repository-name Standards

# Migration Lambda with VPC and Aurora access
ENV=production swift run AWS create-migration-lambda --account 102186460229 --region us-west-2 \
  --stack-name standards-migration-lambda --vpc-stack neonlaw-vpc \
  --aurora-stack neonlaw-aurora-postgres --s3-stack standards-lambda-artifacts \
  --function-name MigrationLambda
```

## Current Deployed Stacks Summary

### Management Account

- SagebrushCLIRole
- ConsoleAccessGroup
- StagingRegionRestriction (SCP)
- oregon-vpc
- oregon-rds (Aurora PostgreSQL)
- oregon-secrets (Secrets Manager)
- sagebrush-alb
- sagebrush-public-bucket
- sagebrush-mailroom-bucket
- sagebrush-cognito-prod
- sagebrush-cognito-dev
- sagebrush-dns (Route53 hosted zone)
- bazaar-service (ECS)

### Production Account

- ConsoleAccessRole
- (Infrastructure to be deployed)

### Staging Account  

- ConsoleAccessRole
- (Infrastructure to be deployed)

### Housekeeping Account

- ConsoleAccessRole
- (Infrastructure to be deployed)

### NeonLaw Account

- ConsoleAccessRole
- GitHubOIDC
- oregon-vpc
- neonlaw-vpc
- neonlaw-aurora-postgres (with Secrets Manager)
- Standards (CodeCommit)
- GreenCrossFarmacy (CodeCommit)
- NLF (CodeCommit)
- standards-lambda-artifacts (S3)
- standards-codebuild
- standards-migration-lambda
