# Deployed AWS Resources

**Last Updated**: 2026-01-14

This document tracks all resources deployed across the 5 AWS accounts.

---

## Management Account (731099197338)

### Lambda Functions

No Lambda functions deployed in this account.

### ECS & Containers

No ECS clusters or ECR repositories deployed in this account.

### Databases

No databases deployed in this account.

### Networking

- **VPCs**:
  - `10.111.0.0/16` (vpc-0a11e850958b9f2a2) - Custom VPC
  - Default VPC: 172.31.0.0/16 (vpc-0a6caa0aefc02a744)

- **NAT Gateways**: None (0 NAT Gateways)

- **Application Load Balancers**: None

### DNS & CDN

- **Route53 Hosted Zone** (`sagebrush-dns`) - Domain: sagebrush.services
  - Hosted Zone ID: `Z08820043FH9K115FO52U`
  - Stack: `sagebrush-dns`
  - Region: `us-west-2`
  - DNS Records:
    - `www.sagebrush.services` → CNAME → `sagebrushservices.pages.dev` (TTL: 300s)
  - Route53 Nameservers:
    - `ns-1982.awsdns-55.co.uk`
    - `ns-1456.awsdns-54.org`
    - `ns-130.awsdns-16.com`
    - `ns-949.awsdns-54.net`
  - **Current Status**: Domain registrar pointing to Cloudflare nameservers (ian.ns.cloudflare.com, mira.ns.cloudflare.com)
  - **Migration Needed**: Update domain registrar to use Route53 nameservers above for DNS changes to take effect
  - Cost: $0.50/month per hosted zone
  - Updated: 2026-01-14

- **CloudFront Distribution** (`sagebrush-brochure-cloudfront`)

### Storage

**No S3 buckets** - All management account buckets deleted during UID-based migration (2026-01-02)

### Authentication & Security

- **Cognito User Pools**: `sagebrush-cognito-dev`, `sagebrush-cognito-prod`, `sagebrush-cognito`
- **Secrets Manager** (`oregon-secrets`) - Database credentials
- **IAM Roles**:
  - `SagebrushCLIRole` - Cross-account CLI access
  - `BillingReadRole` - Cost Explorer access for daily billing reports
    - Trust Policy: Allows Housekeeping account (374073887345) to assume this role
    - Permissions: `ce:GetCostAndUsage`, `ce:GetCostForecast`
    - Purpose: Enables DailyBilling Lambda in Housekeeping account to fetch organization-wide billing data
    - Stack: `BillingReadRole`
    - Created: 2025-12-22

### Services

- **System Accounts**: `sagebrush-github-system-account`, `engineering-system-account`

### Governance

- **Service Control Policy** (`StagingRegionRestriction`)
- **IAM Group** (`ConsoleAccessGroup`) - Cross-account console access

---

## Production Account (978489150794)

### Lambda Functions

- **MigrationRunner** (`standards-migration-lambda` stack)
  - Runtime: provided.al2023 (Swift custom runtime)
  - Architecture: ARM64/Graviton
  - Memory: 512 MB
  - Timeout: 300 seconds (5 minutes)
  - Purpose: Runs Fluent database migrations and seeds for Aurora PostgreSQL
  - VPC: Deployed in private subnets with security group access to Aurora
  - IAM Role: `MigrationRunner-ExecutionRole`
    - Managed Policies: `AWSLambdaVPCAccessExecutionRole` (VPC networking, ENI management, CloudWatch Logs)
    - Inline Policies:
      - `SecretsManagerReadPolicy` - Read Aurora database credentials from Secrets Manager
        - Actions: `secretsmanager:GetSecretValue`, `secretsmanager:DescribeSecret`
        - Resource: Aurora cluster secret ARN
  - Environment Variables:
    - `DATABASE_HOST` - Aurora cluster endpoint
    - `DATABASE_PORT` - PostgreSQL port (5432)
    - `DATABASE_NAME` - Database name
    - `DATABASE_SECRET_ARN` - Secrets Manager ARN for DB credentials
  - S3 Code Location: Referenced by tag `lambda-artifacts` (UID-based bucket name)
  - Code Status: Placeholder (awaits CodeBuild deployment of actual Swift migration code)
  - CloudWatch Logs: `/aws/lambda/MigrationRunner` (7-day retention)
  - Stack: `standards-migration-lambda`
  - Created: 2025-12-21

### Databases

- **Aurora Serverless v2** (`production-aurora-postgres-cluster`)
  - Engine: aurora-postgresql 16.4
  - Instance: db.serverless (`production-aurora-postgres-instance`)
  - Configuration: Min 0.0 ACU, Max 1.0 ACU
  - Auto-pause: 300 seconds (5 minutes)
  - Storage: ~1 GB
  - Created: 2025-12-20
  - Last Updated: 2026-01-01 (deleted interface VPC endpoints)
  - Status: Empty, no connections detected, ready for use
  - Stack: `production-aurora-postgres` (CloudFormation)
  - VPC: `oregon-vpc`
  - Credentials: Stored in Secrets Manager (`production-aurora-postgres-secret`)
  - Cross-account access: Housekeeping account (374073887345)

### Networking

- **VPCs**:
  - `oregon-vpc` - 10.20.0.0/16 (vpc-09672f734d8a70e1f) - Production VPC
  - Default VPC: 172.31.0.0/16 (vpc-033f4cb62327aea2a)

- **VPC Endpoints** (oregon-vpc):
  - S3 Gateway Endpoint (vpce-0d86dca5ecdba3138) - FREE ✅

- **NAT Gateways**: None (0 NAT Gateways)

- **Application Load Balancers**: None

### Storage

**S3 Buckets (UID-Based Naming)** - All buckets use pattern `sagebrush-<account-id>-<uuid>` and are referenced by tags:

- **lambda-artifacts** (Tag: Name)
  - Stack: `prod-lambda-artifacts`
  - Purpose: Lambda deployment packages and build artifacts
  - Versioning: Enabled
  - Created: 2026-01-02

- **user-uploads** (Tag: Name)
  - Stack: `prod-user-uploads`
  - Purpose: Production user file uploads
  - Versioning: Disabled
  - Created: 2026-01-02

- **application-logs** (Tag: Name)
  - Stack: `prod-application-logs`
  - Purpose: Application and Lambda logs
  - Versioning: Disabled
  - Created: 2026-01-02

- **mailroom** (Tag: Name)
  - Stack: `prod-mailroom`
  - Purpose: Physical mail processing and virtual mailbox documents
  - Versioning: Disabled
  - Created: 2026-01-02

- **email** (Tag: Name)
  - Stack: `prod-email`
  - Purpose: Email processing and temporary message storage
  - Versioning: Disabled
  - Created: 2026-01-02

**Tagging Strategy**: All buckets have 5 tags:

- `Name`: Logical reference (e.g., "mailroom")
- `Purpose`: Detailed description
- `Environment`: "production"
- `CostCenter`: "Production"
- `ManagedBy`: "Sagebrush-AWS-CLI"

### ECS & Containers

No ECS clusters or ECR repositories deployed in this account.

### Console Access

- **IAM Role**: `ConsoleAdminAccess` - Administrator access from management account

---

## Staging Account (889786867297)

### Lambda Functions

- **MigrationRunner** (`standards-migration-lambda` stack)
  - Runtime: provided.al2023 (Swift custom runtime)
  - Architecture: ARM64/Graviton
  - Memory: 512 MB
  - Timeout: 300 seconds (5 minutes)
  - Purpose: Runs Fluent database migrations and seeds for Aurora PostgreSQL
  - VPC: Deployed in private subnets with security group access to Aurora
  - IAM Role: `MigrationRunner-ExecutionRole`
    - Managed Policies: `AWSLambdaVPCAccessExecutionRole` (VPC networking, ENI management, CloudWatch Logs)
    - Inline Policies:
      - `SecretsManagerReadPolicy` - Read Aurora database credentials from Secrets Manager
        - Actions: `secretsmanager:GetSecretValue`, `secretsmanager:DescribeSecret`
        - Resource: Aurora cluster secret ARN
  - Environment Variables:
    - `DATABASE_HOST` - Aurora cluster endpoint
    - `DATABASE_PORT` - PostgreSQL port (5432)
    - `DATABASE_NAME` - Database name
    - `DATABASE_SECRET_ARN` - Secrets Manager ARN for DB credentials
  - S3 Code Location: Referenced by tag `lambda-artifacts` (UID-based bucket name)
  - Code Status: Placeholder (awaits CodeBuild deployment of actual Swift migration code)
  - CloudWatch Logs: `/aws/lambda/MigrationRunner` (7-day retention)
  - Stack: `standards-migration-lambda`
  - Created: 2025-12-21

### Databases

- **Aurora Serverless v2** (`staging-aurora-postgres-cluster`)
  - Engine: aurora-postgresql 16.4
  - Instance: db.serverless (`staging-aurora-postgres-instance`)
  - Configuration: Min 0.0 ACU, Max 1.0 ACU
  - Auto-pause: 300 seconds (5 minutes)
  - Storage: ~1 GB
  - Created: 2025-12-21
  - Last Updated: 2026-01-01 (deleted interface VPC endpoints)
  - Status: Empty, no connections detected, ready for use
  - Stack: `staging-aurora-postgres` (CloudFormation)
  - VPC: `oregon-vpc`
  - Credentials: Stored in Secrets Manager (`staging-aurora-postgres-secret`)
  - Cross-account access: Housekeeping account (374073887345)

### Networking

- **VPCs**:
  - `oregon-vpc` - 10.10.0.0/16 (vpc-04a07040639220978) - Staging VPC
  - Default VPC: 172.31.0.0/16 (vpc-0ca9a698761fcd6cc)

- **VPC Endpoints** (oregon-vpc):
  - S3 Gateway Endpoint (vpce-0379dd9b632787903) - FREE ✅

- **NAT Gateways**: None (0 NAT Gateways)

- **Application Load Balancers**: None

### Storage

**S3 Buckets (UID-Based Naming)** - All buckets use pattern `sagebrush-<account-id>-<uuid>` and are referenced by tags:

- **lambda-artifacts** (Tag: Name)
  - Stack: `staging-lambda-artifacts`
  - Purpose: Lambda deployment packages and build artifacts
  - Versioning: Enabled
  - Example: `sagebrush-889786867297-a03c6f24-be0a-432f-9937-8fa015c66591`
  - Created: 2026-01-02

- **user-uploads** (Tag: Name)
  - Stack: `staging-user-uploads`
  - Purpose: Staging user file uploads for testing
  - Versioning: Disabled
  - Created: 2026-01-02

- **application-logs** (Tag: Name)
  - Stack: `staging-application-logs`
  - Purpose: Application and Lambda logs
  - Versioning: Disabled
  - Created: 2026-01-02

- **mailroom** (Tag: Name)
  - Stack: `staging-mailroom`
  - Purpose: Physical mail processing and virtual mailbox documents
  - Versioning: Disabled
  - Created: 2026-01-02

- **email** (Tag: Name)
  - Stack: `staging-email`
  - Purpose: Email processing and temporary message storage
  - Versioning: Disabled
  - Created: 2026-01-02

**Tagging Strategy**: Same as Production (Name, Purpose, Environment: "staging", CostCenter: "Staging", ManagedBy)

### ECS & Containers

No ECS clusters or ECR repositories deployed in this account.

### Governance

- **Service Control Policy**: Region restriction (us-west-2, us-east-1 only)
- **Budget**: $100/month alert threshold

### Console Access

- **IAM Role**: `ConsoleAdminAccess` - Administrator access from management account

---

## Housekeeping Account (374073887345)

### Lambda Functions

- **DailyBilling** (`housekeeping-daily-billing` stack)
  - Runtime: provided.al2 (Swift custom runtime)
  - Architecture: ARM64/Graviton
  - Memory: 128 MB
  - Timeout: 30 seconds
  - Purpose: Fetch and report AWS Organization billing data daily
  - EventBridge Trigger: `cron(0 0 * * ? *)` - Runs daily at midnight UTC (4 PM PST / 5 PM PDT)
  - IAM Role: `DailyBilling-ExecutionRole`
    - Managed Policies: `AWSLambdaBasicExecutionRole` (CloudWatch Logs)
    - Inline Policies:
      - `CostExplorerAccess` - Read cost data
        - Actions: `ce:GetCostAndUsage`, `ce:GetCostForecast`
        - Resource: All (*)
      - `STSAssumeRole` - Assume billing read role in Management account
        - Action: `sts:AssumeRole`
        - Resource: `arn:aws:iam::731099197338:role/BillingReadRole` (Management account)
      - `SESAccess` - Send billing reports via email
        - Actions: `ses:SendEmail`, `ses:SendRawEmail`
        - Resource: All (*)
      - `LambdaS3Access` - Read Lambda code from S3
        - Action: `s3:GetObject`
        - Resource: `arn:aws:s3:::sagebrush-housekeeping-lambda-code/*`
  - Functionality:
    - Assumes `BillingReadRole` in Management account (731099197338)
    - Fetches organization-wide billing data via Cost Explorer API
    - Generates daily cost report for all 5 AWS accounts
    - Sends report via SES email
  - S3 Code Location: Referenced by tag `lambda-code` (UID-based bucket name)
  - CloudWatch Logs: `/aws/lambda/DailyBilling` (7-day retention)
  - EventBridge Rule: `DailyBilling-FiveMinuteCron` (ENABLED)
  - Stack: `housekeeping-daily-billing`
  - Created: 2025-12-22
  - Last Updated: 2025-12-22

### Storage

**S3 Buckets (UID-Based Naming)** - All buckets use pattern `sagebrush-<account-id>-<uuid>` and are referenced by tags:

- **lambda-code** (Tag: Name)
  - Stack: `housekeeping-lambda-code`
  - Purpose: DailyBilling and housekeeping Lambda functions
  - Versioning: Enabled
  - Example: `sagebrush-374073887345-48f12c83-7f4e-4dd4-8ef0-a9cfa48a151d`
  - Created: 2026-01-02

- **billing-reports** (Tag: Name)
  - Stack: `housekeeping-billing-reports`
  - Purpose: Daily billing reports and cost data exports
  - Versioning: Disabled
  - Created: 2026-01-02

- **archive** (Tag: Name)
  - Stack: `housekeeping-archive`
  - Purpose: Cross-account backups and disaster recovery
  - Versioning: Disabled
  - Created: 2026-01-02

**Tagging Strategy**: Same as other accounts (Name, Purpose, Environment: "housekeeping", CostCenter: "Housekeeping", ManagedBy)

### Networking

- **VPCs**:
  - Default VPC only: 172.31.0.0/16 (vpc-03203feecf18b09b8)

- **NAT Gateways**: None (0 NAT Gateways) ✅

- **Application Load Balancers**: None

### ECS & Containers

No ECS clusters or ECR repositories deployed in this account.

### Email Infrastructure

- **SES Domain Identity**: sagebrush.services
- **SES Email Identity**: <support@sagebrush.services>
- **DKIM**: Enabled (3 tokens in Route53)
- **Status**: Sandbox mode (pending production access request)

### Console Access

- **IAM Role**: `ConsoleAdminAccess` - Administrator access from management account

---

## NeonLaw Account (102186460229)

### Lambda Functions

- **MigrationRunner** (`standards-migration-lambda` stack)
  - Runtime: provided.al2023 (Swift custom runtime)
  - Architecture: ARM64/Graviton
  - Memory: 512 MB
  - Timeout: 300 seconds (5 minutes)
  - Purpose: Runs Fluent database migrations and seeds for Aurora PostgreSQL
  - VPC: Deployed in private subnets with security group access to Aurora
  - IAM Role: `MigrationRunner-ExecutionRole`
    - Managed Policies: `AWSLambdaVPCAccessExecutionRole` (VPC networking, ENI management, CloudWatch Logs)
    - Inline Policies:
      - `SecretsManagerReadPolicy` - Read Aurora database credentials from Secrets Manager
        - Actions: `secretsmanager:GetSecretValue`, `secretsmanager:DescribeSecret`
        - Resource: Aurora cluster secret ARN
  - Environment Variables:
    - `DATABASE_HOST` - Aurora cluster endpoint
    - `DATABASE_PORT` - PostgreSQL port (5432)
    - `DATABASE_NAME` - Database name
    - `DATABASE_SECRET_ARN` - Secrets Manager ARN for DB credentials
  - S3 Code Location: Referenced by tag `lambda-artifacts` (UID-based bucket name)
  - Code Status: Placeholder (awaits CodeBuild deployment of actual Swift migration code)
  - CloudWatch Logs: `/aws/lambda/MigrationRunner` (7-day retention)
  - Stack: `standards-migration-lambda`
  - Created: 2025-12-21

### Databases

- **Aurora Serverless v2** (`neonlaw-aurora-postgres-cluster`)
  - Engine: aurora-postgresql 16.4
  - Instance: db.serverless (`neonlaw-aurora-postgres-instance`)
  - Configuration: Min 0.0 ACU, Max 1.0 ACU
  - Auto-pause: 300 seconds (5 minutes)
  - Storage: ~1 GB
  - Created: 2025-12-20
  - Last Updated: 2026-01-01 (deleted interface VPC endpoints)
  - Status: Empty, no connections detected, ready for use
  - Stack: `neonlaw-aurora-postgres` (CloudFormation)
  - VPC: `oregon-vpc`
  - Credentials: Stored in Secrets Manager (`neonlaw-aurora-postgres-secret`)
  - Cross-account access: Housekeeping account (374073887345)

### Networking

- **VPCs**:
  - `oregon-vpc` - 10.30.0.0/16 (vpc-0016806a300d8c301) - NeonLaw VPC
  - Default VPC: 172.31.0.0/16 (vpc-0a713c88737032a0b)

- **VPC Endpoints** (oregon-vpc):
  - S3 Gateway Endpoint (vpce-0949b81b031e7dea9) - FREE ✅

- **NAT Gateways**: None (0 NAT Gateways)

- **Application Load Balancers**: None

### Storage

**S3 Buckets (UID-Based Naming)** - All buckets use pattern `sagebrush-<account-id>-<uuid>` and are referenced by tags:

- **lambda-artifacts** (Tag: Name)
  - Stack: `neonlaw-lambda-artifacts`
  - Purpose: Lambda deployment packages and build artifacts
  - Versioning: Enabled
  - Example: `sagebrush-102186460229-2764bbea-8d3a-4390-864a-88f2e33334ce`
  - Created: 2026-01-02

- **user-uploads** (Tag: Name)
  - Stack: `neonlaw-user-uploads`
  - Purpose: NeonLaw user file uploads
  - Versioning: Disabled
  - Created: 2026-01-02

- **application-logs** (Tag: Name)
  - Stack: `neonlaw-application-logs`
  - Purpose: Application and Lambda logs
  - Versioning: Disabled
  - Created: 2026-01-02

- **email** (Tag: Name)
  - Stack: `neonlaw-email`
  - Purpose: Email processing and temporary message storage
  - Versioning: Disabled
  - Created: 2026-01-02

**Tagging Strategy**: Same as other accounts (Name, Purpose, Environment: "neonlaw", CostCenter: "NeonLaw", ManagedBy)

### ECS & Containers

No ECS clusters or ECR repositories deployed in this account.

### Code Repositories (CodeCommit)

- `GreenCrossFarmacy` - Green Cross Farmacy legal standards
- `NLF` - Neon Law Foundation standards
- `Sagebrush` - Sagebrush legal standards
- `SagebrushHoldingCompany` - Holding company standards
- `ShookEstate` - Shook Estate legal standards

### Console Access

- **IAM Role**: `ConsoleAdminAccess` - Administrator access from management account

---

## Infrastructure as Code Stacks

This section documents available CloudFormation stacks that can be deployed on-demand across accounts.

### GitHubMirrorStack (Deployed - 9 Active Stacks)

**Purpose**: Automated GitHub → CodeCommit mirroring infrastructure

**What It Creates**:
- CodeCommit repository for mirrored code
- IAM user for GitHub Actions authentication (e.g., `github-sagebrush-web-staging`)
- IAM policy with least privilege (GitPull/GitPush to specific repo only)
- Access key for GitHub Actions

**Deployed Stacks (2026-01-12)**:

**Staging Account (889786867297) - 3 stacks**:
1. `sagebrush-web-staging-mirror` → Repo: `sagebrush-web` | User: `github-sagebrush-web-staging`
2. `sagebrush-api-staging-mirror` → Repo: `sagebrush-api` | User: `github-sagebrush-api-staging`
3. `sagebrush-operations-staging-mirror` → Repo: `sagebrush-operations` | User: `github-sagebrush-operations-staging`

**Production Account (978489150794) - 3 stacks**:
1. `sagebrush-web-prod-mirror` → Repo: `sagebrush-web` | User: `github-sagebrush-web-production`
2. `sagebrush-api-prod-mirror` → Repo: `sagebrush-api` | User: `github-sagebrush-api-production`
3. `sagebrush-operations-prod-mirror` → Repo: `sagebrush-operations` | User: `github-sagebrush-operations-production`

**NeonLaw Account (102186460229) - 3 stacks**:
1. `neon-law-web-prod-mirror` → Repo: `neon-law-web` | User: `github-neon-law-web-production`
2. `neon-law-api-prod-mirror` → Repo: `neon-law-api` | User: `github-neon-law-api-production`
3. `nlf-web-prod-mirror` → Repo: `nlf-web` | User: `github-nlf-web-production`

**CLI Command**:
```bash
ENV=production swift run AWS create-github-mirror \
  --account <account-id> \
  --region us-west-2 \
  --stack-name <repo>-<env>-mirror \
  --repository-name <repo> \
  --environment <staging|production>
```

**Benefits**:
- Infrastructure as code (version-controlled Swift templates)
- Single command deploys all resources
- Guaranteed least-privilege security
- Easy cleanup (delete stack removes all resources)

**Next Steps**:
1. Retrieve access keys from CloudFormation outputs
2. Add AWS credentials to GitHub repository secrets
3. Create GitHub Actions workflows (see `CODECOMMIT_INTEGRATION_ROADMAP.md`)

**Documentation**: See `CODECOMMIT_INTEGRATION_ROADMAP.md` for complete implementation guide

---

## Cost Summary (Estimated Monthly)

**Last Cost Review**: 2026-01-11

| Account | Current Cost | Notes |
| ------- | ------------ | ----- |
| Management | ~$1-6/month | Route53 ($0.50), CloudFront ($0-5), Secrets ($0.40), Cognito (free) |
| Production | ~$1/month | Aurora paused ($0.10), Lambda (<$0.10), S3 ($0.10-1), Secrets ($0.40) |
| Staging | ~$1/month | Aurora paused ($0.10), Lambda (<$0.10), S3 ($0.10-1), Secrets ($0.40) |
| Housekeeping | ~$1-2/month | Lambda ($0.05), S3 ($0.10-1), SES (free tier) |
| NeonLaw | ~$1/month | Aurora paused ($0.10), Lambda (<$0.10), S3 ($0.10-1), Secrets ($0.40), CodeCommit (free) |
| **TOTAL** | **~$5-12/month** | **All Aurora databases paused. If all active 24/7: ~$270-280/month** |

### Cost Optimization Notes

- ✅ **NAT Gateways: 0** across all accounts (saves ~$160/month for 5 gateways)
- ✅ **Aurora Serverless v2**: Auto-pause configured (5 min) on all 3 databases
- ✅ **S3 VPC Gateway Endpoints**: Free tier in Production, Staging, NeonLaw
- ✅ **Application Load Balancers: 0** across all accounts (deleted idle Management ALB)
- ℹ️ **Aurora Database Cost**: Each database costs ~$0.10/month when paused, ~$87/month when active (1.0 ACU max)

### Recent Changes

- **2026-01-12**: Deployed GitHub → CodeCommit mirroring infrastructure (9 GitHubMirrorStack stacks across 3 accounts)
  - Staging: sagebrush-web, sagebrush-api, sagebrush-operations
  - Production: sagebrush-web, sagebrush-api, sagebrush-operations
  - NeonLaw: neon-law-web, neon-law-api, nlf-web
  - Cost: $0 (CodeCommit first 5 users free, additional users $1/month)
- **2026-01-11**: Deleted Management Account resources (RDS PostgreSQL, ECS cluster/service, ECR repos, ALB +
  target groups) - Saves ~$60-70/month total
- **2026-01-02**: Migrated to UID-based S3 bucket naming across all accounts
- **2026-01-01**: Deleted VPC interface endpoints in Production, Staging, NeonLaw - Saves ~$21/month
- **2025-12-22**: Deployed DailyBilling Lambda in Housekeeping account
- **2025-12-21**: Deployed MigrationRunner Lambda in Staging, Production, NeonLaw accounts
- **2025-12-20**: Created Aurora Serverless v2 databases in Production, Staging, NeonLaw accounts
