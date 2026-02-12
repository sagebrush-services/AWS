# Aurora Serverless v2 Deployment Guide

## Summary

Aurora Postgres infrastructure is ready to deploy with:

- ✅ Auto-generated credentials (Secrets Manager)
- ✅ Cross-account secret access (housekeeping account)
- ✅ Aurora Serverless v2 (0.5-1 ACU scaling)
- ✅ VPC private subnet deployment
- ✅ Security groups for Lambda access

## Status

### ✅ Working

- **LocalStack**: Successfully deployed and tested
- **Management Account (731099197338)**: Successfully deployed and verified

### ❌ Blocked in Child Accounts

- **Staging (889786867297)**: Blocked - Permission issue
- **Production (978489150794)**: Blocked - Permission issue
- **NeonLaw (102186460229)**: Blocked - Permission issue

## Root Cause

The `SagebrushCLIRole` lacks permissions for:

1. **Secrets Manager** operations
2. **IAM CreateServiceLinkedRole** (required by RDS)

## Solution

### Updated IAMStack.swift

I've already updated `Sources/Stacks/IAMStack.swift` with the required permissions:

**Added Secrets Manager permissions:**

```json
{
  "Sid": "SecretsManagerAccess",
  "Effect": "Allow",
  "Action": [
    "secretsmanager:CreateSecret",
    "secretsmanager:DeleteSecret",
    "secretsmanager:DescribeSecret",
    "secretsmanager:GetSecretValue",
    "secretsmanager:PutSecretValue",
    "secretsmanager:UpdateSecret",
    "secretsmanager:TagResource",
    "secretsmanager:UntagResource",
    "secretsmanager:PutResourcePolicy",
    "secretsmanager:DeleteResourcePolicy",
    "secretsmanager:GetResourcePolicy"
  ],
  "Resource": "*"
}
```

**Added IAM Service-Linked Role permissions:**

```json
"iam:CreateServiceLinkedRole",
"iam:DeleteServiceLinkedRole",
"iam:GetServiceLinkedRoleDeletionStatus"
```

### Deployment Options

#### Option 1: AWS Console (Recommended for First-Time Setup)

1. Navigate to CloudFormation in each child account
2. Update the `SagebrushCLIRole` stack
3. Use the template from `Sources/Stacks/IAMStack.swift`
4. Parameters:
   - `ManagementAccountId`: `731099197338`

#### Option 2: Direct AWS CLI (If you have root/admin access)

For each account, run from management account with appropriate credentials:

```bash
# Staging (889786867297)
aws cloudformation update-stack \\
  --stack-name SagebrushCLIRole \\
  --template-body file://$(swift run AWS 2>&1 | grep -A10000 IAMStack | jq -r .templateBody) \\
  --region us-west-2 \\
  --capabilities CAPABILITY_NAMED_IAM \\
  --parameters ParameterKey=ManagementAccountId,ParameterValue=731099197338

# Production (978489150794)
aws cloudformation update-stack \\
  --stack-name SagebrushCLIRole \\
  --template-body file://template.json \\
  --region us-west-2 \\
  --capabilities CAPABILITY_NAMED_IAM \\
  --parameters ParameterKey=ManagementAccountId,ParameterValue=731099197338

# NeonLaw (102186460229)
aws cloudformation update-stack \\
  --stack-name SagebrushCLIRole \\
  --template-body file://template.json \\
  --region us-west-2 \\
  --capabilities CAPABILITY_NAMED_IAM \\
  --parameters ParameterKey=ManagementAccountId,ParameterValue=731099197338
```

#### Option 3: Organizations StackSets (Most Scalable)

If you want to manage this across all accounts:

```bash
aws cloudformation create-stack-set \\
  --stack-set-name SagebrushCLIRole \\
  --template-body file://template.json \\
  --capabilities CAPABILITY_NAMED_IAM \\
  --parameters ParameterKey=ManagementAccountId,ParameterValue=731099197338 \\
  --permission-model SERVICE_MANAGED \\
  --auto-deployment Enabled=true,RetainStacksOnAccountRemoval=false

aws cloudformation create-stack-instances \\
  --stack-set-name SagebrushCLIRole \\
  --deployment-targets OrganizationalUnitIds=ou-dk1g-hnppfrn3 \\
  --regions us-west-2
```

## After Updating Permissions

Once the `SagebrushCLIRole` has been updated in all accounts, deploy Aurora:

```bash
# Staging
ENV=production .build/release/AWS create-aurora-postgres \\
  --account 889786867297 \\
  --region us-west-2 \\
  --stack-name staging-aurora-postgres \\
  --vpc-stack oregon-vpc \\
  --db-name app \\
  --db-username postgres \\
  --min-capacity 0.5 \\
  --max-capacity 1

# Production
ENV=production .build/release/AWS create-aurora-postgres \\
  --account 978489150794 \\
  --region us-west-2 \\
  --stack-name production-aurora-postgres \\
  --vpc-stack oregon-vpc \\
  --db-name app \\
  --db-username postgres \\
  --min-capacity 0.5 \\
  --max-capacity 1

# NeonLaw
ENV=production .build/release/AWS create-aurora-postgres \\
  --account 102186460229 \\
  --region us-west-2 \\
  --stack-name neonlaw-aurora-postgres \\
  --vpc-stack oregon-vpc \\
  --db-name app \\
  --db-username postgres \\
  --min-capacity 0.5 \\
  --max-capacity 1
```

## Verifying Deployment

After deployment, verify Aurora is running:

```bash
# Check cluster status
aws rds describe-db-clusters \\
  --db-cluster-identifier <stack-name>-cluster \\
  --region us-west-2 \\
  --query 'DBClusters[0].{Status:Status,Engine:Engine,ServerlessV2:ServerlessV2ScalingConfiguration}'

# Get secret ARN
aws cloudformation describe-stacks \\
  --stack-name <stack-name> \\
  --region us-west-2 \\
  --query 'Stacks[0].Outputs[?OutputKey==`SecretArn`].OutputValue' \\
  --output text

# Test secret access from housekeeping account
aws secretsmanager get-secret-value \\
  --secret-id <secret-arn> \\
  --region us-west-2
```

## Cross-Account Access from Housekeeping

The database secrets are accessible from the housekeeping account (374073887345):

```bash
# From housekeeping account
aws secretsmanager get-secret-value \\
  --secret-id <secret-arn-from-other-account> \\
  --region us-west-2
```

The secret contains:

- `username`: postgres
- `password`: auto-generated 32-char password
- Connection details (added by SecretTargetAttachment):
  - `host`: cluster endpoint
  - `port`: 5432
  - `dbname`: app
  - `engine`: postgres

## Infrastructure Files

All infrastructure is code in this repo:

- **Aurora Stack**: `Sources/Stacks/AuroraPostgresStack.swift`
- **IAM Role**: `Sources/Stacks/IAMStack.swift`
- **CLI Commands**: `Sources/main.swift`
- **Tests**: `Tests/AuroraPostgresTests.swift`

## Architecture

```text
┌─────────────────────────────────────────┐
│  Staging Account (889786867297)         │
│  ┌─────────────────────────────────┐    │
│  │ Aurora Serverless v2 PostgreSQL │    │
│  │ - Private Subnet                │    │
│  │ - Security Group (VPC access)   │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │ Secrets Manager                 │    │
│  │ - Auto-generated credentials    │    │
│  │ - Connection URL                │    │
│  │ - Cross-account policy         │────┼──┐
│  └─────────────────────────────────┘    │  │
└─────────────────────────────────────────┘  │
                                             │
┌─────────────────────────────────────────┐  │
│  Housekeeping Account (374073887345)    │  │
│  ┌─────────────────────────────────┐    │  │
│  │ Lambda Functions                │    │  │
│  │ - Can read secrets             │◄───┼──┘
│  │ - Connect to databases          │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

## Notes

- Aurora Serverless v2 requires at least 2 AZs for deployment
- The VPC stack `oregon-vpc` provides 3 private subnets across 3 AZs
- All databases use encryption at rest
- Backup retention is 7 days
- CloudWatch Logs exports are enabled for PostgreSQL logs
