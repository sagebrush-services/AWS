# Sagebrush AWS Infrastructure CLI

A Swift-based CLI tool for managing the AWS accounts of the trifecta.

> **CONFIDENTIAL AND PROPRIETARY**
> This repository contains proprietary infrastructure code for Sagebrush Services LLC.
> This repository is and will always remain private. Unauthorized access, use, or distribution is strictly prohibited.
> Copyright © 2025 Sagebrush Services LLC. All rights reserved.

## Claude Code Development Setup

This project is part of the [Trifecta](https://github.com/neon-law-foundation/Trifecta) development
environment, designed for full-stack Swift development with Claude Code.

**Recommended Setup**: Use the [Trifecta configuration](https://github.com/neon-law-foundation/Trifecta) which provides:

- Unified Claude Code configuration across all projects
- Pre-configured shell aliases for quick navigation
- Consistent development patterns and tooling
- Automated repository cloning and setup

**Working in Isolation**: This repository can also be developed independently. We maintain separate
repositories (rather than a monorepo) to ensure:

- **Clear code boundaries** - Each project has distinct responsibilities and scope
- **Legal delineation** - Clear separation between software consumed by different entities (Neon Law
  Foundation, Neon Law, Sagebrush Services)
- **Independent deployment** - Each service can be versioned and deployed separately
- **Focused development** - Smaller, more manageable codebases

## AWS Organization Structure

The Sagebrush infrastructure is organized under an AWS Organization with
multiple accounts for different purposes:

### Accounts

| Account | Account ID | Email | Purpose | Created |
| --------- | ----------- | ------- | --------- | --------- |
| **Management** | 731099197338 | <sagebrush@shook.family> | AWS Organization management account | 2025/06/16 |
| **Production** | 978489150794 | <sagebrush-prod@shook.family> | Production workloads and services | 2025/11/29 |
| **Staging** | 889786867297 | <sagebrush-staging@shook.family> | Pre-production testing environment | 2025/11/29 |
| **Housekeeping** | 374073887345 | <sagebrush-housekeeping@shook.family> | Operational tooling and maintenance | 2025/11/29 |
| **NeonLaw** | 102186460229 | <neon-law@shook.family> | NeonLaw application infrastructure | 2025/11/29 |

> We use shook.family as the primary account ID to use a service managed
> outside of AWS.

### Account Usage Guidelines

- **Management**: Use for AWS Organizations configuration, billing, and
  cross-account IAM roles. Do not deploy application workloads here.
- **Production**: Deploy production services and infrastructure. Use
  `--account 978489150794` with this CLI.
- **Staging**: Test infrastructure changes and deployments before promoting to
  production. Use `--account 889786867297`.
- **Housekeeping**: Deploy operational tools like monitoring, log aggregation,
  and CI/CD infrastructure. Use `--account 374073887345`.
- **NeonLaw**: Dedicated account for NeonLaw application resources, isolated
  from other Sagebrush services. Use `--account 102186460229`.

### AWS Organizations Governance

The organization uses **Service Control Policies (SCPs)** to enforce security
and cost controls across all child accounts:

#### Active Service Control Policies

##### 1. DenyNATGatewayCreation (Policy ID: p-i8ojldu1)

- **Purpose**: Prevents creation of NAT Gateways to enforce VPC endpoint usage
- **Applied to**: Production, Staging, Housekeeping, NeonLaw accounts
- **Rationale**: NAT Gateways cost $32-45/month each. VPC endpoints provide the
  same functionality at lower cost ($0 for S3 gateway endpoints, ~$7/month for
  interface endpoints)
- **Deployed**: 2025-12-31
- **Exception**: Management account can still create NAT Gateways if absolutely
  necessary (via OrganizationAccountAccessRole)

Why This Matters:

All AWS Lambda functions in child accounts use VPC endpoints to access AWS
services (S3, Secrets Manager, CloudWatch Logs, ECR) instead of NAT Gateways.
This reduces monthly costs by approximately $192-270/month while maintaining
the same functionality.

If You Need NAT Gateway Access:

NAT Gateways are blocked to prevent accidental costly deployments. If you
legitimately need internet access for a specific use case that VPC endpoints
cannot solve, contact the infrastructure team to evaluate alternatives or create
a time-limited exception.

##### 2. Region Restrictions

- **Staging Account**: Restricted to us-west-2 and us-east-1 only
- **Purpose**: Prevent accidental deployments to expensive or distant regions
- **Deployed**: 2025-12-20

#### Future Governance Plans

Additional SCPs may be added to:

- Enforce encryption at rest for all storage services
- Restrict expensive instance types in non-production accounts
- Prevent public S3 buckets without explicit approval
- Require MFA for sensitive operations

## Documentation

This repository contains several documentation resources to help you manage AWS infrastructure:

### Quick Reference Guides

- **[INFRASTRUCTURE_COMMANDS.md](./INFRASTRUCTURE_COMMANDS.md)**: Complete CLI command reference for all accounts
  - Management account infrastructure (VPC, RDS, S3, ALB, Route53, SES)
  - Production account setup and deployment
  - Staging account setup and budget configuration
  - Housekeeping account operational tools
  - NeonLaw account infrastructure and CI/CD
  - LocalStack development and testing commands

- **[AURORA_DEPLOYMENT_GUIDE.md](./AURORA_DEPLOYMENT_GUIDE.md)**: Aurora PostgreSQL deployment and configuration
  - Aurora Serverless v2 setup
  - Database migration workflows
  - Connection string management
  - Secrets Manager integration

### Architecture Diagrams

**Automated Diagram Generation** using official AWS architecture icons:

```bash
cd diagrams
uv run generate.py
```

This generates 6 detailed PNG diagrams based on `DEPLOYED_RESOURCES.md`:

- **00-organization-overview.png** - AWS Organization structure and
  cross-account relationships
- **01-management-account.png** - Management account (731099197338) with ECS,
  RDS, ALB, Cognito, etc.
- **02-production-account.png** - Production account (978489150794) with Aurora
  Serverless v2
- **03-staging-account.png** - Staging account (889786867297) with Aurora
  Serverless v2
- **04-housekeeping-account.png** - Housekeeping account (374073887345) with
  daily billing Lambda
- **05-neonlaw-account.png** - NeonLaw account (102186460229) with Aurora and
  CodeCommit

See **[diagrams/README.md](./diagrams/README.md)** for full documentation on
diagram generation, customization, and updating diagrams when infrastructure
changes.

## Production Deployment: Route53 DNS and SES Email

This section provides step-by-step instructions for deploying Route53 DNS and AWS SES for the
**sagebrush.services** domain in production.

### Migration Overview

This deployment involves **two phases**:

1. **DNS Migration** (immediate): Migrate DNS hosting from CloudFlare to Route53 by updating
   nameservers
2. **Domain Registration Transfer** (after DNS migration): Transfer domain ownership from CloudFlare
   Registrar to AWS Route53 Registrar

**Goal**: The domain `sagebrush.services` will be **owned and renewed in perpetuity** by AWS Route53 in
the management account (731099197338).

**Complete migration instructions**: See `~/Downloads/DNS_MOVE.md` for detailed DNS and domain transfer procedures.

### Prerequisites

1. **AWS Credentials**: Management account credentials set as environment variables

   ```bash
   export AWS_ACCESS_KEY_ID="your-management-account-access-key"
   export AWS_SECRET_ACCESS_KEY="your-management-account-secret-key"
   export AWS_DEFAULT_REGION="us-west-2"
   ```

2. **IAM Roles Deployed**: Ensure `SagebrushCLIRole` is deployed to all accounts

   ```bash
   # If not already deployed, run:
   ENV=production swift run AWS create-iam --region us-west-2
   ENV=production swift run AWS create-iam --account housekeeping --region us-west-2
   ```

### Step 1: Deploy Route53 Hosted Zone (Management Account)

Deploy the hosted zone in the **Management account** to get nameservers for domain transfer:

```bash
ENV=production swift run AWS create-route53 \
  --region us-west-2 \
  --stack-name sagebrush-dns \
  --domain-name sagebrush.services
```

**Expected Output:**

```text
✅ Route53 hosted zone stack created successfully: sagebrush-dns

📝 Next steps:
   1. Get nameservers from CloudFormation outputs
   2. Update domain registrar with these nameservers
   3. Wait 24-48 hours for DNS propagation
```

**Get Nameservers:**

```bash
aws cloudformation describe-stacks \
  --region us-west-2 \
  --stack-name sagebrush-dns \
  --query 'Stacks[0].Outputs[?OutputKey==`NameServers`].OutputValue' \
  --output text
```

**Save the 4 nameservers** - you'll need them for CloudFlare in Step 3.

### Step 2: Deploy SES Domain Identity (Housekeeping Account)

Deploy SES in the **Housekeeping account** to generate DKIM tokens:

```bash
ENV=production swift run AWS create-ses \
  --account housekeeping \
  --region us-west-2 \
  --stack-name sagebrush-ses \
  --domain-name sagebrush.services \
  --email-address support@sagebrush.services
```

**Expected Output:**

```text
✅ SES domain identity stack created successfully: sagebrush-ses

📝 Next steps:
   1. Get DKIM tokens from CloudFormation outputs
   2. Update Route53 stack with DKIM records
```

**Get DKIM Tokens:**

```bash
# Get all DKIM outputs
aws cloudformation describe-stacks \
  --region us-west-2 \
  --stack-name sagebrush-ses \
  --query 'Stacks[0].Outputs[?starts_with(OutputKey, `DKIM`)].{Key:OutputKey,Value:OutputValue}' \
  --output table
```

**Save all 6 values**: DKIMToken1/2/3 and DKIMValue1/2/3

### Step 3: Update CloudFlare Nameservers (DNS Migration - Phase 1)

**Note**: This step migrates DNS hosting only. Domain registration transfer happens later (see `~/Downloads/DNS_MOVE.md`).

While waiting for SES DKIM tokens to propagate, update CloudFlare:

1. **Log in to CloudFlare**: <https://dash.cloudflare.com>
2. **Navigate to sagebrush.services**
3. **Go to DNS → Settings** (NOT Domain Registration)
4. **Change Nameservers**:
   - Click "Change nameservers"
   - Select "Custom nameservers"
   - Add the 4 nameservers from Step 1
   - Save changes

**⚠️ Important**:

- DNS propagation takes 24-48 hours
- Do NOT delete CloudFlare DNS settings yet
- Do NOT initiate domain transfer yet (wait for DNS propagation)

### Step 4: Update Route53 with SES DKIM Records

Once you have the DKIM tokens from Step 2, update the Route53 stack:

```bash
ENV=production swift run AWS create-route53 \
  --region us-west-2 \
  --stack-name sagebrush-dns \
  --domain-name sagebrush.services \
  --mx-record "10 inbound-smtp.us-west-2.amazonaws.com" \
  --spf-record "v=spf1 include:amazonses.com ~all" \
  --dmarc-record "v=DMARC1; p=quarantine; rua=mailto:dmarc@sagebrush.services" \
  --dkim-token1 "<DKIMToken1-from-step-2>" \
  --dkim-value1 "<DKIMValue1-from-step-2>" \
  --dkim-token2 "<DKIMToken2-from-step-2>" \
  --dkim-value2 "<DKIMValue2-from-step-2>" \
  --dkim-token3 "<DKIMToken3-from-step-2>" \
  --dkim-value3 "<DKIMValue3-from-step-2>"
```

**Replace** `<DKIMToken1-from-step-2>` etc. with actual values from Step 2.

### Step 5: Verify DNS Propagation

Monitor nameserver propagation:

```bash
# Check current nameservers (repeat every few hours)
dig NS sagebrush.services

# Check from Google DNS
dig NS sagebrush.services @8.8.8.8

# Check from CloudFlare DNS
dig NS sagebrush.services @1.1.1.1

# Verify Route53 is responding
dig sagebrush.services @<nameserver-from-step-1>
```

**When successful**, you'll see the Route53 nameservers returned.

### Step 6: Verify SES Domain

Check SES domain verification status:

```bash
# Check domain verification
aws sesv2 get-email-identity \
  --region us-west-2 \
  --email-identity sagebrush.services \
  --query 'DkimAttributes.Status' \
  --output text
```

**Expected**: `SUCCESS` (once DNS propagates)

### Step 7: Request SES Production Access

By default, SES is in **sandbox mode** (can only send to verified addresses).

**To send to any email address:**

1. Go to AWS Console → SES (in us-west-2)
2. Switch to **Housekeeping account** (374073887345)
3. Navigate to **Account dashboard**
4. Click **Request production access**
5. Fill out the form:
   - **Mail type**: Transactional
   - **Website URL**: <https://sagebrush.services>
   - **Use case description**: "Transactional emails for legal services platform (password resets, notifications, alerts)"
   - **Process for handling bounces/complaints**: "Monitor SES bounce and complaint notifications via CloudWatch"
6. Submit request

**Approval time**: Typically 24 hours

### Step 8: Add ALB DNS Records (After ALB Deployment)

Once you deploy ALBs in production and staging accounts, update Route53 with DNS records:

```bash
# Get ALB DNS names
PROD_ALB_DNS=$(aws elbv2 describe-load-balancers \
  --region us-west-2 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `prod`)].DNSName' \
  --output text)

STAGING_ALB_DNS=$(aws elbv2 describe-load-balancers \
  --region us-west-2 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `staging`)].DNSName' \
  --output text)

# Update Route53
ENV=production swift run AWS create-route53 \
  --region us-west-2 \
  --stack-name sagebrush-dns \
  --domain-name sagebrush.services \
  --www-target "$PROD_ALB_DNS" \
  --staging-target "$STAGING_ALB_DNS"
```

### Step 9: Test Email Sending

Once SES is verified and in production access:

```bash
# Send test email from support@sagebrush.services
aws sesv2 send-email \
  --region us-west-2 \
  --from-email-address support@sagebrush.services \
  --destination ToAddresses=your-email@example.com \
  --content "Subject={Data=Test Email from Sagebrush},Body={Text={Data=This is a test email from sagebrush.services}}"
```

### Deployment Checklist

#### Phase 1: DNS Migration

- [ ] Step 1: Deploy Route53 hosted zone
- [ ] Step 2: Deploy SES domain identity
- [ ] Step 3: Update CloudFlare nameservers (DNS only)
- [ ] Step 4: Update Route53 with DKIM records
- [ ] Step 5: Verify DNS propagation (24-48 hours)
- [ ] Step 6: Verify SES domain verification
- [ ] Step 7: Request SES production access
- [ ] Step 8: Add ALB DNS records (after ALB deployment)
- [ ] Step 9: Test email sending

#### Phase 2: Domain Registration Transfer

(see `~/Downloads/DNS_MOVE.md`)

- [ ] Unlock domain in CloudFlare Registrar (after 48+ hours of DNS propagation)
- [ ] Get EPP/authorization code from CloudFlare
- [ ] Initiate domain transfer in AWS Route53 (management account)
- [ ] Approve transfer at CloudFlare and AWS
- [ ] Verify transfer complete (5-7 days)
- [ ] Enable auto-renewal in AWS Route53
- [ ] Configure billing alerts for domain renewals

### Rollback Procedure

If issues occur:

1. **Revert CloudFlare Nameservers**: Change back to CloudFlare's nameservers
2. **Delete CloudFormation Stacks**:

   ```bash
   ENV=production swift run AWS delete-stack --region us-west-2 --stack-name sagebrush-dns
   ENV=production swift run AWS delete-stack --account housekeeping --region us-west-2 --stack-name sagebrush-ses
   ```

3. **Verify**: Domain resolves via CloudFlare again

### Authentication with STS AssumeRole

This CLI uses **STS AssumeRole** for cross-account access, which means you only
need **ONE set of credentials** to access all 5 accounts. No `~/.aws/config`
file is required.

#### How It Works

1. You provide base credentials via environment variables (typically from the
   Management account)
2. The CLI uses STS to assume a role in the target account
3. Temporary credentials are automatically generated and used for that account

#### Setup Requirements

**In the Management Account (731099197338)**:

- Create an IAM user with `sts:AssumeRole` permission
- Store the IAM user's credentials as environment variables

**In Each Target Account** (Production, Staging, Housekeeping, NeonLaw):

- Create an IAM role named `SagebrushCLIRole`
- Configure trust relationship to allow the Management account to assume it
- Attach necessary permissions (CloudFormation, EC2, RDS, S3, etc.)

#### Setting Credentials

Set these environment variables **once** - they work for all accounts:

```bash
export AWS_ACCESS_KEY_ID="your-management-account-access-key"
export AWS_SECRET_ACCESS_KEY="your-management-account-secret-key"
export AWS_DEFAULT_REGION="us-west-2"
```

These same credentials will be used to assume roles in all 5 accounts.

### Quick Answer: One Set of Credentials for All Accounts

**Yes!** The same `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` work for all
5 accounts.

You only need to set your Management account credentials **once**, and the CLI
automatically uses STS AssumeRole to access any of the 5 accounts by specifying
the `--account` parameter. No configuration files needed.

```bash
# Set once
export AWS_ACCESS_KEY_ID="management-account-key"
export AWS_SECRET_ACCESS_KEY="management-account-secret"

# Works for Production
swift run AWS create-vpc --account 978489150794 --region us-west-2 --stack-name prod-vpc

# Works for Staging (same credentials!)
swift run AWS create-vpc --account 889786867297 --region us-west-2 --stack-name staging-vpc

# Works for all 5 accounts (same credentials!)
```

## Installation

```bash
cd ~/Code/Sagebrush/AWS
swift build -c release
```

The binary will be available at `.build/release/AWS`.

## Initial Setup: Deploy IAM Roles

**CRITICAL**: Before deploying any infrastructure, you must deploy the
`SagebrushCLIRole` IAM role to each account. This role allows cross-account
access from the Management account.

### Step 1: Deploy to Management Account (Required First!)

Deploy the IAM role to the **Management account** first. This account will be
used to assume roles in all other accounts:

```bash
# Ensure you have Management account credentials set
export AWS_ACCESS_KEY_ID="your-management-account-access-key"
export AWS_SECRET_ACCESS_KEY="your-management-account-secret-key"
export AWS_DEFAULT_REGION="us-west-2"

# Deploy IAM role to Management account (without --account flag)
ENV=production swift run AWS create-iam --region us-west-2
```

This creates the `SagebrushCLIRole` in the Management account with:

- **Trust Policy**: Allows Management account to assume role with ExternalId
  `sagebrush-cli`
- **Permissions**: Least privilege access for CloudFormation and all supported
  AWS services
- **Services**: CloudFormation, CodeCommit, S3, RDS, VPC, ECS, Lambda, ALB,
  Route53, ACM, EventBridge, IAM, CloudWatch Logs

### Step 2: Deploy to All Other Accounts

After the Management account has the role, deploy it to all other accounts using
the `--account` flag:

```bash
# Deploy to NeonLaw account
ENV=production swift run AWS create-iam --account neonlaw --region us-west-2

# Deploy to Production account
ENV=production swift run AWS create-iam --account production --region us-west-2

# Deploy to Staging account
ENV=production swift run AWS create-iam --account staging --region us-west-2

# Deploy to Housekeeping account
ENV=production swift run AWS create-iam --account housekeeping --region us-west-2
```

### Step 3: Verify IAM Setup

Verify the role was created successfully:

```bash
# Test assuming role in NeonLaw account
aws sts assume-role \
  --role-arn arn:aws:iam::102186460229:role/SagebrushCLIRole \
  --role-session-name test \
  --external-id sagebrush-cli
```

If successful, you'll receive temporary credentials. Now you're ready to deploy
infrastructure!

### Step 4: Deploy Resources

Now you can deploy any infrastructure to any account using the `--account` flag:

```bash
# Example: Deploy CodeCommit repository to NeonLaw account
ENV=production swift run AWS create-codecommit \
  --account neonlaw \
  --region us-west-2 \
  --stack-name GreenCrossFarmacy \
  --repository-name GreenCrossFarmacy
```

### Testing IAM Setup Locally with LocalStack

Before deploying to production, test the IAM stack locally:

```bash
# Start LocalStack
localstack start

# Set test credentials
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"

# Deploy IAM stack to LocalStack (no ENV=production needed)
swift run AWS create-iam --region us-west-2

# Verify role was created
aws --endpoint-url=http://localhost:4566 \
  iam get-role --role-name SagebrushCLIRole

# Verify policy was attached
aws --endpoint-url=http://localhost:4566 \
  iam list-attached-role-policies --role-name SagebrushCLIRole

# Deploy a test resource (CodeCommit)
swift run AWS create-codecommit \
  --region us-west-2 \
  --stack-name TestRepo \
  --repository-name TestRepo
```

### Security Features

The `SagebrushCLIRole` includes several AWS security best practices:

1. **ExternalId**: Prevents confused deputy attacks by requiring
   `sagebrush-cli` ExternalId
2. **Least Privilege**: Only grants permissions needed for CloudFormation
   operations
3. **Service-Specific**: Scoped permissions for each AWS service (CodeCommit,
   S3, RDS, etc.)
4. **Trust Relationship**: Only the Management account (731099197338) can assume
   these roles
5. **IAM Passthrough**: Limited IAM permissions only for what CloudFormation
   needs to create service roles

## LocalStack - Local Development

This CLI automatically uses **LocalStack** for local development, allowing you
to test AWS infrastructure without cloud costs or internet connectivity.

### Environment Detection

The CLI automatically detects which environment to use:

- **Development (default)**: Uses LocalStack at
  `http://localhost.localstack.cloud:4566`
- **Production**: Uses real AWS endpoints when `ENV=production`

### Setting Up LocalStack

1. **Install LocalStack**:

   ```bash
   brew install localstack
   ```

2. **Start LocalStack**:

   ```bash
   localstack start
   ```

   LocalStack runs on port **4566** and is accessible at
   `http://localhost.localstack.cloud:4566`.

3. **Configure Test Credentials**:
   For LocalStack, use test credentials:

   ```bash
   export AWS_ACCESS_KEY_ID="test"
   export AWS_SECRET_ACCESS_KEY="test"
   export AWS_DEFAULT_REGION="us-east-1"
   ```

   If you already have AWS credentials configured, LocalStack will use them (but
   they can be any value for local testing).

### Local vs Production Usage

**Local Development** (uses LocalStack):

```bash
# No ENV variable needed - LocalStack is the default
swift run AWS create-vpc --stack-name dev-vpc --region us-east-1
```

**Production** (uses real AWS):

```bash
# Set ENV=production to use real AWS
ENV=production swift run AWS create-vpc \
  --profile production \
  --region us-west-2 \
  --stack-name prod-vpc
```

### Benefits of LocalStack

- **Fast iteration** - Test infrastructure changes instantly
- **Cost-free** - No AWS charges during development
- **Offline capable** - Work without internet connectivity
- **Safe testing** - Experiment without affecting production

### Verifying LocalStack

After starting LocalStack, verify it's working:

```bash
# List CloudFormation stacks in LocalStack
aws cloudformation list-stacks \
  --endpoint-url=http://localhost.localstack.cloud:4566 \
  --region us-east-1
```

## Prerequisites

- Swift 6.0 or later
- **LocalStack** for local development (optional, see below)
- AWS CLI configured with credentials for production
- AWS account with appropriate permissions for production

## Authentication

### Account-Based Authentication (Recommended)

Use the `--account` parameter to specify which account to deploy to. The CLI
uses STS AssumeRole to automatically obtain temporary credentials for that
account.

```bash
# Set base credentials once
export AWS_ACCESS_KEY_ID="your-management-account-access-key"
export AWS_SECRET_ACCESS_KEY="your-management-account-secret-key"

# Deploy to production
swift run AWS create-vpc \
  --account 978489150794 \
  --region us-west-2 \
  --stack-name prod-vpc

# Deploy to staging
swift run AWS create-vpc \
  --account 889786867297 \
  --region us-west-2 \
  --stack-name staging-vpc
```

### Profile-Based Authentication (Legacy)

You can still use AWS profiles if you have them configured:

```bash
swift run AWS create-vpc --profile my-profile --region us-west-2 --stack-name my-vpc
```

**Note**: When using `--account`, the `--profile` parameter is ignored.

## Cross-Account Console Access

Enable users to switch between AWS accounts in the web console using IAM roles.

### Current Deployment Status

**Deployed on**: 2025-12-20

Cross-account console access has been successfully configured for all accounts:

- ✅ **Production** (978489150794): `ConsoleAdminAccess` role deployed
- ✅ **Staging** (889786867297): `ConsoleAdminAccess` role deployed
- ✅ **Housekeeping** (374073887345): `ConsoleAdminAccess` role deployed
- ✅ **NeonLaw** (102186460229): `ConsoleAdminAccess` role deployed
- ✅ **Management** (731099197338): `CrossAccountAdministrators` group created

**Quick Access Links for admin users:**

- [Switch to Production](https://signin.aws.amazon.com/switchrole?roleName=ConsoleAdminAccess&account=978489150794&displayName=Production)
- [Switch to Staging](https://signin.aws.amazon.com/switchrole?roleName=ConsoleAdminAccess&account=889786867297&displayName=Staging)
- [Switch to Housekeeping](https://signin.aws.amazon.com/switchrole?roleName=ConsoleAdminAccess&account=374073887345&displayName=Housekeeping)
- [Switch to NeonLaw](https://signin.aws.amazon.com/switchrole?roleName=ConsoleAdminAccess&account=102186460229&displayName=NeonLaw)

### Overview

This feature allows users in the **Management account** to seamlessly switch to
other accounts (Production, Staging, Housekeeping, NeonLaw) in the AWS Console
without needing separate credentials for each account.

**Benefits:**

- Single set of credentials for all accounts
- Easy account switching via AWS Console UI
- Secure role-based access control
- Configurable permission levels (Administrator, PowerUser, ReadOnly)
- No need to log out and back in

### Architecture

1. **Target Accounts**: Deploy a `ConsoleAccessRole` IAM role that trusts the
   Management account
2. **Management Account**: Deploy a `CrossAccountAdministrators` IAM group with
   permissions to assume the roles
3. **Users**: Add IAM users to the group to grant console access

### Setup Instructions

#### Step 1: Deploy Roles to Target Accounts

Deploy the console access role to each target account (Production, Staging,
Housekeeping, NeonLaw):

```bash
# Deploy to Production account
ENV=production swift run AWS create-console-access-role \
  --account production \
  --region us-west-2 \
  --stack-name ConsoleAccessRole \
  --role-name ConsoleAdminAccess \
  --permission-level Administrator

# Deploy to Staging account
ENV=production swift run AWS create-console-access-role \
  --account staging \
  --region us-west-2 \
  --stack-name ConsoleAccessRole \
  --role-name ConsoleAdminAccess \
  --permission-level Administrator

# Deploy to Housekeeping account
ENV=production swift run AWS create-console-access-role \
  --account housekeeping \
  --region us-west-2 \
  --stack-name ConsoleAccessRole \
  --role-name ConsoleAdminAccess \
  --permission-level Administrator

# Deploy to NeonLaw account
ENV=production swift run AWS create-console-access-role \
  --account neonlaw \
  --region us-west-2 \
  --stack-name ConsoleAccessRole \
  --role-name ConsoleAdminAccess \
  --permission-level Administrator
```

**Permission Levels:**

- `Administrator`: Full access to all AWS services (AdministratorAccess policy)
- `PowerUser`: Full access except IAM (PowerUserAccess policy)
- `ReadOnly`: Read-only access to all AWS services (ReadOnlyAccess policy)

#### Step 2: Deploy IAM Group to Management Account

Deploy the IAM group and policies in the **Management account** (731099197338):

```bash
ENV=production swift run AWS create-console-access-group \
  --region us-west-2 \
  --stack-name ConsoleAccessGroup \
  --group-name CrossAccountAdministrators \
  --target-role-name ConsoleAdminAccess
```

This creates:

- An IAM group named `CrossAccountAdministrators`
- A managed policy that allows assuming the `ConsoleAdminAccess` role in all 4
  target accounts
- Permissions for users to change their own passwords and manage SSH keys

#### Step 3: Add Users to the Group

Add existing IAM users to the `CrossAccountAdministrators` group:

**Via AWS Console:**

1. Sign in to the Management account (731099197338)
2. Navigate to **IAM** → **Groups**
3. Select **CrossAccountAdministrators**
4. Click **Add Users to Group**
5. Select the users you want to grant access
6. Click **Add Users**

**Via AWS CLI:**

```bash
# Add a user to the group
aws iam add-user-to-group \
  --group-name CrossAccountAdministrators \
  --user-name <username>
```

#### Step 4: Switch Roles in the Console

Users can now switch roles using the AWS Console:

##### Method 1: Using Direct Links

After deploying the stacks, the CLI outputs direct links for each account:

- **Production**:
  `https://signin.aws.amazon.com/switchrole?roleName=ConsoleAdminAccess&account=978489150794&displayName=Production`
- **Staging**:
  `https://signin.aws.amazon.com/switchrole?roleName=ConsoleAdminAccess&account=889786867297&displayName=Staging`
- **Housekeeping**:
  `https://signin.aws.amazon.com/switchrole?roleName=ConsoleAdminAccess&account=374073887345&displayName=Housekeeping`
- **NeonLaw**:
  `https://signin.aws.amazon.com/switchrole?roleName=ConsoleAdminAccess&account=102186460229&displayName=NeonLaw`

##### Method 2: Manual Switch Role

1. Sign in to the Management account (731099197338)
2. Click your username in the top-right corner
3. Select **Switch Roles**
4. Enter:
   - **Account**: Target account ID (e.g., `978489150794` for Production)
   - **Role**: `ConsoleAdminAccess`
   - **Display Name**: A friendly name (e.g., "Production")
   - **Color**: (Optional) Choose a color to distinguish the account
5. Click **Switch Role**

**Switching Back:**

- Click the role display name in the top-right corner
- Select **Back to [Your Username]**

**Recent Roles:**

The AWS Console remembers the last 5 roles you've switched to, making it easy to
switch between accounts quickly.

### Configuration Options

#### Custom Role Names

If you want to use a different role name:

```bash
# Use a custom role name
ENV=production swift run AWS create-console-access-role \
  --account production \
  --role-name CustomRoleName \
  --permission-level PowerUser

# Update the group to match
ENV=production swift run AWS create-console-access-group \
  --target-role-name CustomRoleName
```

#### Session Duration

Configure how long console sessions last (default: 1 hour):

```bash
# Allow 4-hour sessions
ENV=production swift run AWS create-console-access-role \
  --account production \
  --max-session-duration 14400  # 4 hours in seconds
```

#### MFA Requirement

To require multi-factor authentication (MFA), uncomment the MFA condition in
`ConsoleAccessRoleStack.swift`:

```swift
// In the trust policy, add:
"Condition": {
  "Bool": {
    "aws:MultiFactorAuthPresent": "true"
  }
}
```

### Security Best Practices

1. **Use MFA**: Require MFA for production account access
2. **Principle of Least Privilege**: Use `PowerUser` or `ReadOnly` instead of
   `Administrator` when possible
3. **Audit Access**: Use CloudTrail to monitor who assumes roles and when
4. **Regular Reviews**: Periodically review group membership and remove users
   who no longer need access
5. **Session Duration**: Use shorter session durations for sensitive accounts

### Troubleshooting

#### Error: "You don't have permission to assume this role"

- Verify the user is in the `CrossAccountAdministrators` group
- Check that the role exists in the target account
- Ensure the role name matches exactly (case-sensitive)

#### Error: "Invalid account or role"

- Verify the account ID is correct (12 digits)
- Check that the role name is correct
- Ensure the role's trust policy allows the Management account

**Session expires too quickly:**

- Increase `MaxSessionDuration` when deploying the role
- Note: Maximum is 12 hours (43200 seconds)

## Commands

### Create IAM Role

Create the `SagebrushCLIRole` IAM role for cross-account access. This must be
deployed to all accounts before any other infrastructure.

```bash
# Deploy to Management account first (no --account flag)
ENV=production swift run AWS create-iam --region us-west-2

# Then deploy to other accounts
ENV=production swift run AWS create-iam \
  --account neonlaw \
  --region us-west-2
```

**Options:**

- `--account`: AWS account to target (optional, uses STS AssumeRole)
- `--profile`: AWS profile name (optional, legacy authentication)
- `--region`: AWS region (default: us-west-2)
- `--stack-name`: CloudFormation stack name (default: SagebrushCLIRole)
- `--management-account-id`: Management account ID (default: 731099197338)

**Outputs:**

- Role ARN
- Role Name

**Security:**

- Trust policy requires ExternalId `sagebrush-cli`
- Least privilege permissions for CloudFormation operations
- Service-specific scoped permissions

### Create Console Access Role

Create a cross-account IAM role for console access in a target account. This
allows users from the Management account to switch to this account via the AWS
Console.

```bash
# Deploy to Production account
ENV=production swift run AWS create-console-access-role \
  --account production \
  --region us-west-2 \
  --stack-name ConsoleAccessRole \
  --role-name ConsoleAdminAccess \
  --permission-level Administrator
```

**Options:**

- `--account`: AWS account to target (optional, uses STS AssumeRole)
- `--profile`: AWS profile name (optional, legacy authentication)
- `--region`: AWS region (default: us-west-2)
- `--stack-name`: CloudFormation stack name (default: ConsoleAccessRole)
- `--management-account-id`: Management account ID (default: 731099197338)
- `--role-name`: Name of the IAM role (default: ConsoleAdminAccess)
- `--permission-level`: Permission level - Administrator, PowerUser, or ReadOnly
  (default: Administrator)
- `--max-session-duration`: Maximum session duration in seconds (default: 3600,
  max: 43200)

**Outputs:**

- Role ARN
- Role Name
- Direct console switch link
- Account ID

**Features:**

- Trust relationship with Management account
- Configurable permission levels using AWS managed policies
- Customizable session duration (1-12 hours)
- Direct console switch links for easy access

### Create Console Access Group

Create an IAM group and policies in the Management account that grants users
permission to assume console access roles in target accounts.

```bash
# Deploy to Management account
ENV=production swift run AWS create-console-access-group \
  --region us-west-2 \
  --stack-name ConsoleAccessGroup \
  --group-name CrossAccountAdministrators
```

**Options:**

- `--profile`: AWS profile name (optional)
- `--region`: AWS region (default: us-west-2)
- `--stack-name`: CloudFormation stack name (default: ConsoleAccessGroup)
- `--group-name`: IAM group name (default: CrossAccountAdministrators)
- `--production-account-id`: Production account ID (default: 978489150794)
- `--staging-account-id`: Staging account ID (default: 889786867297)
- `--housekeeping-account-id`: Housekeeping account ID (default: 374073887345)
- `--neonlaw-account-id`: NeonLaw account ID (default: 102186460229)
- `--target-role-name`: Name of role in target accounts (default:
  ConsoleAdminAccess)

**Outputs:**

- Group name
- Group ARN
- Policy ARN
- Console switch links for all 4 target accounts

**Features:**

- Grants `sts:AssumeRole` permission for all target accounts
- Includes password change and SSH key management permissions
- Provides direct console switch links for easy access
- Supports adding multiple users to the group

### Create CodeCommit Repository

Create a CodeCommit Git repository for source code hosting.

```bash
ENV=production swift run AWS create-codecommit \
  --account neonlaw \
  --region us-west-2 \
  --stack-name GreenCrossFarmacy \
  --repository-name GreenCrossFarmacy
```

**Options:**

- `--account`: AWS account to target (optional, uses STS AssumeRole)
- `--profile`: AWS profile name (optional, legacy authentication)
- `--region`: AWS region (default: us-west-2)
- `--stack-name`: CloudFormation stack name
- `--repository-name`: CodeCommit repository name

**Outputs:**

- Repository name
- Repository ARN
- Clone URL (HTTP)
- Clone URL (SSH)

**Features:**

- Default branch: main
- Git repository for source code
- Integrates with AWS CodePipeline and CodeBuild
- IAM-based access control

#### Neon Law Standards Repositories

The following CodeCommit repositories have been created in the **NeonLaw account** (102186460229) for managing Neon Law
legal standards and documentation:

| Repository | Purpose | Clone URL |
| ---------- | ------- | --------- |
| **GreenCrossFarmacy** | Green Cross Farmacy standards | [CodeCommit][gcf-url] |
| **NLF** | Neon Law Foundation standards | [CodeCommit][nlf-url] |
| **Sagebrush** | Sagebrush legal standards | [CodeCommit][sb-url] |
| **SagebrushHoldingCompany** | Sagebrush Holding Company standards | [CodeCommit][shc-url] |
| **ShookEstate** | Shook Estate legal standards | [CodeCommit][se-url] |

[gcf-url]: https://git-codecommit.us-west-2.amazonaws.com/v1/repos/GreenCrossFarmacy
[nlf-url]: https://git-codecommit.us-west-2.amazonaws.com/v1/repos/NLF
[sb-url]: https://git-codecommit.us-west-2.amazonaws.com/v1/repos/Sagebrush
[shc-url]: https://git-codecommit.us-west-2.amazonaws.com/v1/repos/SagebrushHoldingCompany
[se-url]: https://git-codecommit.us-west-2.amazonaws.com/v1/repos/ShookEstate

These repositories are managed from the `~/Standards` directory on local development machines. Each repository contains
legal documents, contracts, and standards specific to its respective entity.

**Creating Additional Standards Repositories:**

```bash
ENV=production swift run AWS create-codecommit \
  --account neonlaw \
  --region us-west-2 \
  --stack-name <RepositoryName> \
  --repository-name <RepositoryName>
```

**Cloning Standards Repositories:**

```bash
git clone https://git-codecommit.us-west-2.amazonaws.com/v1/repos/<RepositoryName>
```

### Create VPC

Create a VPC with public and private subnets across two availability zones,
including NAT Gateway for private subnet internet access.

```bash
swift run AWS create-vpc \
  --account 978489150794 \
  --region us-west-2 \
  --stack-name prod-vpc \
  --class-b 10
```

**Options:**

- `--account`: AWS account ID to target (optional, uses STS AssumeRole)
- `--profile`: AWS profile name (optional, legacy authentication)
- `--region`: AWS region (default: us-west-2)
- `--stack-name`: CloudFormation stack name
- `--class-b`: Class B of VPC (10.XXX.0.0/16) (default: 10)

**Outputs:**

- VPC ID
- Public subnet IDs
- Private subnet IDs
- VPC CIDR block

### Create ECS Cluster

Create an ECS cluster with Fargate support, IAM roles, and CloudWatch logging.

```bash
swift run AWS create-ecs \
  --account 978489150794 \
  --region us-west-2 \
  --stack-name prod-ecs \
  --vpc-stack prod-vpc \
  --cluster-name production-cluster
```

**Options:**

- `--account`: AWS account ID to target (optional, uses STS AssumeRole)
- `--profile`: AWS profile name (optional, legacy authentication)
- `--region`: AWS region (default: us-west-2)
- `--stack-name`: CloudFormation stack name
- `--vpc-stack`: Name of the VPC stack to reference
- `--cluster-name`: ECS cluster name (default: app-cluster)

**Outputs:**

- Cluster name
- Cluster ARN
- Task execution role ARN
- Task role ARN
- Security group ID
- CloudWatch log group name

### Create RDS PostgreSQL Database

Create an RDS PostgreSQL database in private subnets with encryption and
automated backups.

```bash
swift run AWS create-rds \
  --account 978489150794 \
  --region us-west-2 \
  --stack-name prod-rds \
  --vpc-stack prod-vpc \
  --db-name production \
  --db-username postgres \
  --db-password 'MySecurePassword123' \
  --min-capacity 0.5 \
  --max-capacity 2
```

**Options:**

- `--account`: AWS account ID to target (optional, uses STS AssumeRole)
- `--profile`: AWS profile name (optional, legacy authentication)
- `--region`: AWS region (default: us-west-2)
- `--stack-name`: CloudFormation stack name
- `--vpc-stack`: Name of the VPC stack to reference
- `--db-name`: Database name (default: app)
- `--db-username`: Database username (default: postgres)
- `--db-password`: Database password (required)
- `--min-capacity`: Minimum Aurora Serverless v2 capacity (default: 0.5)
- `--max-capacity`: Maximum Aurora Serverless v2 capacity (default: 1)

**Outputs:**

- Database endpoint
- Database port
- Database name
- Complete database URL

**Security:**

- Database is in private subnets (not publicly accessible)
- Encryption at rest enabled
- Automated backups (7 days retention)
- Performance Insights enabled

### Create S3 Bucket

Create an S3 bucket with versioning, encryption, and lifecycle policies.

```bash
swift run AWS create-s3 \
  --account 978489150794 \
  --region us-west-2 \
  --stack-name prod-public-bucket \
  --bucket-name sagebrush-production-assets \
  --public-access
```

**Options:**

- `--account`: AWS account ID to target (optional, uses STS AssumeRole)
- `--profile`: AWS profile name (optional, legacy authentication)
- `--region`: AWS region (default: us-west-2)
- `--stack-name`: CloudFormation stack name
- `--bucket-name`: S3 bucket name (must be globally unique)
- `--public-access`: Allow public access (optional flag)

**Outputs:**

- Bucket name
- Bucket ARN
- Bucket domain name

**Features:**

- Server-side encryption (AES256)
- Versioning enabled
- Lifecycle policy (deletes old versions after 90 days)
- Public access blocked by default

### Create Lambda Function

Create a Lambda function with EventBridge cron trigger (every 5 minutes). All
Lambda functions use **AWS Graviton (ARM64)** processors for optimal
price/performance.

```bash
swift run AWS create-lambda \
  --account 978489150794 \
  --region us-west-2 \
  --stack-name prod-lambda \
  --s3-stack prod-private-bucket \
  --function-name FiveMinuteFunction \
  --s3-key lambdas/five_minutes/bootstrap.zip
```

**Options:**

- `--account`: AWS account ID to target (optional, uses STS AssumeRole)
- `--profile`: AWS profile name (optional, legacy authentication)
- `--region`: AWS region (default: us-west-2)
- `--stack-name`: CloudFormation stack name
- `--s3-stack`: Name of the S3 stack containing Lambda code
- `--function-name`: Lambda function name (default: FiveMinuteFunction)
- `--s3-key`: S3 key path to Lambda deployment package (default:
  lambdas/five_minutes/bootstrap.zip)

**Outputs:**

- Function name
- Function ARN
- EventBridge rule name
- CloudWatch log group name

**Features:**

- **Graviton (ARM64)** architecture for better price/performance
- Custom runtime (`provided.al2023`) for Swift Lambda functions
- EventBridge cron trigger (every 5 minutes)
- CloudWatch Logs integration (7 day retention)
- IAM execution role with S3 read access
- 30 second timeout, 128 MB memory

**Architecture Note:**

All Lambda functions are automatically configured to use AWS Graviton2/Graviton3
processors (`arm64` architecture). This provides better price/performance
compared to x86_64 (Intel/AMD) processors. Ensure your Lambda deployment package
is compiled for ARM64.

### Create Application Load Balancer

Create an Application Load Balancer with Route53 DNS integration for ECS
services.

**Production Deployment for <www.sagebrush.services>:**

The Sagebrush Services website (<www.sagebrush.services>) should be deployed to
the **Production account** (978489150794):

```bash
swift run AWS create-alb \
  --account 978489150794 \
  --region us-west-2 \
  --stack-name prod-alb \
  --vpc-stack prod-vpc \
  --ecs-stack prod-ecs \
  --domain-name www.sagebrush.services
```

**Options:**

- `--account`: AWS account ID to target (optional, uses STS AssumeRole)
- `--profile`: AWS profile name (optional, legacy authentication)
- `--region`: AWS region (default: us-west-2)
- `--stack-name`: CloudFormation stack name
- `--vpc-stack`: Name of the VPC stack to reference
- `--ecs-stack`: Name of the ECS stack to reference
- `--domain-name`: Domain name for the application (default: <www.sagebrush.services>)

**Outputs:**

- Load Balancer DNS name
- Load Balancer ARN
- Target Group ARN
- Route53 Hosted Zone ID
- Application URL

**Features:**

- Internet-facing Application Load Balancer
- HTTP listener on port 80
- Target group with IP target type (for Fargate)
- Route53 hosted zone and DNS record
- Automatic integration with ECS services

**Multi-Account Deployment:**

When deploying to different environments, use the appropriate AWS account:

- **Production** (`--account 978489150794`): For `www.sagebrush.services` and
  other production domains
- **Staging** (`--account 889786867297`): For `staging.sagebrush.services` or
  pre-production testing
- **NeonLaw** (`--account 102186460229`): For NeonLaw-specific domains

Each account should have its own VPC and ECS cluster to maintain environment
isolation.

### Create Budget

Create an AWS Budget with cost alerts and notifications via email and SNS.

```bash
# Create a $100/month budget for the staging account
ENV=production swift run AWS create-budget \
  --account staging \
  --region us-west-2 \
  --stack-name StagingBudget \
  --budget-name "Staging Monthly Budget" \
  --budget-amount 100 \
  --email-address your-email@example.com \
  --threshold-percentage 80
```

**Options:**

- `--account`: AWS account to target (optional, uses STS AssumeRole)
- `--profile`: AWS profile name (optional, legacy authentication)
- `--region`: AWS region (default: us-west-2)
- `--stack-name`: CloudFormation stack name (default: MonthlyBudget)
- `--budget-name`: Name of the budget (default: MonthlyBudget)
- `--budget-amount`: Monthly budget amount in USD (default: 100)
- `--email-address`: Email address for notifications (required)
- `--threshold-percentage`: Alert threshold percentage (default: 80)

**Outputs:**

- Budget name
- Budget amount
- SNS topic ARN for notifications
- Alert threshold percentage

**Features:**

- Email and SNS notifications at threshold (e.g., 80% of budget)
- Forecasted cost alerts when projected to exceed 100%
- Tracks all costs including taxes, subscriptions, and support
- Monthly budget period with automatic reset

#### Example: Staging Account Budget

```bash
# Set up $100/month budget for staging account (889786867297)
ENV=production swift run AWS create-budget \
  --account 889786867297 \
  --region us-west-2 \
  --budget-amount 100 \
  --email-address admin@example.com
```

### Create Service Control Policy (SCP)

Create a Service Control Policy to restrict AWS API calls to specific regions.
This must be deployed to the **Management account** (731099197338).

```bash
# Create SCP to restrict staging account to us-west-2 and us-east-1
ENV=production swift run AWS create-scp \
  --region us-west-2 \
  --stack-name StagingRegionRestriction \
  --policy-name "RestrictStagingRegions" \
  --policy-description "Limits staging to us-west-2 and us-east-1" \
  --allowed-region1 us-west-2 \
  --allowed-region2 us-east-1 \
  --target-account-id 889786867297
```

**Options:**

- `--account`: AWS account to target (must be management account)
- `--profile`: AWS profile name (optional, legacy authentication)
- `--region`: AWS region (default: us-west-2)
- `--stack-name`: CloudFormation stack name (default: RegionRestrictionSCP)
- `--policy-name`: Name of the SCP (default: RestrictRegions)
- `--policy-description`: Description of the SCP
- `--allowed-region1`: First allowed region (default: us-west-2)
- `--allowed-region2`: Second allowed region (default: us-east-1)
- `--target-account-id`: Account ID to attach SCP to (optional)

**Outputs:**

- Policy ID
- Policy name
- Allowed regions
- CLI command to manually attach policy (if target account not specified)

**Features:**

- Denies all AWS API calls outside specified regions
- Exempts global services (IAM, CloudFront, Route53, etc.)
- Can be attached to accounts or organizational units
- Provides immediate enforcement (no new resources outside allowed regions)

**Important Notes:**

1. **Must run in Management account**: SCPs can only be created in the AWS
   Organizations management account (731099197338)
2. **Global services exempted**: IAM, Route53, CloudFront, and other global
   services continue to work
3. **Immediate effect**: Once attached, the SCP immediately restricts API calls
4. **Cannot be bypassed**: Even account administrators cannot override SCPs

#### Example: Complete Staging Account Setup

```bash
# Step 1: Create SCP in Management account to restrict regions
ENV=production swift run AWS create-scp \
  --region us-west-2 \
  --policy-name "StagingRegionRestriction" \
  --allowed-region1 us-west-2 \
  --allowed-region2 us-east-1 \
  --target-account-id 889786867297

# Step 2: Create budget in Staging account
ENV=production swift run AWS create-budget \
  --account 889786867297 \
  --region us-west-2 \
  --budget-amount 100 \
  --email-address admin@example.com
```

This setup ensures the staging account can only deploy resources in us-west-2
and us-east-1, and will send alerts when costs approach $100/month.

### Create Route53 Hosted Zone

Create a Route53 hosted zone with optional DNS records for www, staging, email (MX), and SES DKIM verification.

**Create basic hosted zone in Management account:**

```bash
ENV=production swift run AWS create-route53 \
  --region us-west-2 \
  --stack-name sagebrush-dns \
  --domain-name sagebrush.services
```

**Options:**

- `--profile`: AWS profile name (optional)
- `--region`: AWS region (default: us-west-2)
- `--stack-name`: CloudFormation stack name (default: sagebrush-dns)
- `--domain-name`: Domain name (default: sagebrush.services)
- `--www-target`: ALB DNS name for www subdomain (optional)
- `--staging-target`: ALB DNS name for staging subdomain (optional)
- `--mx-record`: MX record value for email (optional)
- `--spf-record`: SPF TXT record value (optional)
- `--dmarc-record`: DMARC TXT record value (optional)
- `--dkim-token1/2/3`: SES DKIM tokens (optional)
- `--dkim-value1/2/3`: SES DKIM values (optional)

**Outputs:**

- Hosted Zone ID
- Name servers (for domain transfer)
- Domain name

**Features:**

- Conditional DNS records (only created if parameters provided)
- Support for www and staging CNAME records
- Email configuration (MX, SPF, DMARC, DKIM)
- Centralized DNS management for all accounts

**Example: Complete DNS setup with ALB and email:**

```bash
# Step 1: Create hosted zone
ENV=production swift run AWS create-route53 \
  --region us-west-2 \
  --stack-name sagebrush-dns \
  --domain-name sagebrush.services

# Step 2: After deploying ALBs, update with DNS records
ENV=production swift run AWS create-route53 \
  --region us-west-2 \
  --stack-name sagebrush-dns \
  --domain-name sagebrush.services \
  --www-target "prod-alb-1234567890.us-west-2.elb.amazonaws.com" \
  --staging-target "staging-alb-0987654321.us-west-2.elb.amazonaws.com"

# Step 3: After deploying SES, update with email records
ENV=production swift run AWS create-route53 \
  --region us-west-2 \
  --stack-name sagebrush-dns \
  --domain-name sagebrush.services \
  --mx-record "10 inbound-smtp.us-west-2.amazonaws.com" \
  --spf-record "v=spf1 include:amazonses.com ~all" \
  --dmarc-record "v=DMARC1; p=quarantine; rua=mailto:dmarc@sagebrush.services" \
  --dkim-token1 "<token1>" --dkim-value1 "<value1>" \
  --dkim-token2 "<token2>" --dkim-value2 "<value2>" \
  --dkim-token3 "<token3>" --dkim-value3 "<value3>"
```

### Create SES Domain Identity

Create AWS SES (Simple Email Service) domain and email identities for sending emails.

**Deploy to housekeeping account:**

```bash
ENV=production swift run AWS create-ses \
  --account housekeeping \
  --region us-west-2 \
  --stack-name sagebrush-ses \
  --domain-name sagebrush.services \
  --email-address support@sagebrush.services
```

**Options:**

- `--account`: AWS account to target (default: housekeeping)
- `--profile`: AWS profile name (optional)
- `--region`: AWS region (default: us-west-2)
- `--stack-name`: CloudFormation stack name (default: sagebrush-ses)
- `--domain-name`: Domain name (default: sagebrush.services)
- `--email-address`: Email address to verify (default: <support@sagebrush.services>)

**Outputs:**

- Domain Identity ARN
- Email Identity ARN
- DKIM Token 1/2/3 (names for CNAME records)
- DKIM Value 1/2/3 (targets for CNAME records)

**Features:**

- Domain verification for sending from any @sagebrush.services address
- Email verification for specific sender addresses
- DKIM signing enabled (RSA 2048-bit)
- Automatic DKIM token generation

**Complete SES Setup Workflow:**

```bash
# Step 1: Deploy SES in housekeeping account
ENV=production swift run AWS create-ses \
  --account housekeeping \
  --region us-west-2 \
  --stack-name sagebrush-ses \
  --domain-name sagebrush.services \
  --email-address support@sagebrush.services

# Step 2: Copy DKIM tokens from CloudFormation outputs
# You'll see outputs like:
#   DKIMToken1: abc123xyz._domainkey
#   DKIMValue1: abc123xyz.dkim.amazonses.com
#   (repeat for Token2/Value2 and Token3/Value3)

# Step 3: Update Route53 with DKIM records (see Route53 example above)

# Step 4: Wait for DNS propagation (a few minutes)

# Step 5: AWS will automatically verify the domain

# Step 6: Request production access (to send to any email)
# Go to AWS SES Console → Account dashboard → Request production access
```

**Important Notes:**

1. **SES Sandbox**: By default, SES is in sandbox mode (can only send to verified addresses)
2. **Production Access**: Request it via SES console to send to any email
3. **DKIM Required**: Must add DKIM records to Route53 for domain verification
4. **Email Verification**: Individual email addresses are verified immediately
5. **Domain Verification**: Domain verification requires DNS records

### Domain Transfer from CloudFlare to Route53

Transfer the sagebrush.services domain from CloudFlare to AWS Route53.

#### Step 1: Deploy Route53 Hosted Zone

```bash
ENV=production swift run AWS create-route53 \
  --region us-west-2 \
  --stack-name sagebrush-dns \
  --domain-name sagebrush.services
```

#### Step 2: Get Nameservers from CloudFormation

```bash
# View CloudFormation outputs
aws cloudformation describe-stacks \
  --region us-west-2 \
  --stack-name sagebrush-dns \
  --query 'Stacks[0].Outputs'

# Or use AWS Console:
# CloudFormation → sagebrush-dns → Outputs tab
# Look for "NameServers" output
```

You'll see 4 nameservers like:

- ns-1234.awsdns-12.org
- ns-5678.awsdns-56.com
- ns-9012.awsdns-90.net
- ns-3456.awsdns-34.co.uk

#### Step 3: Update CloudFlare Nameservers

1. Log in to CloudFlare
2. Navigate to sagebrush.services domain
3. Go to DNS → Settings
4. Change nameservers from CloudFlare to the 4 AWS Route53 nameservers
5. Save changes

#### Step 4: Wait for DNS Propagation

DNS propagation can take 24-48 hours globally. Monitor with:

```bash
# Check current nameservers
dig NS sagebrush.services

# Check from multiple locations
dig NS sagebrush.services @8.8.8.8  # Google DNS
dig NS sagebrush.services @1.1.1.1  # Cloudflare DNS

# Verify Route53 is responding
dig sagebrush.services @ns-1234.awsdns-12.org
```

#### Step 5: Verify Domain Transfer

Once nameservers have propagated:

```bash
# Verify SOA record
dig SOA sagebrush.services

# Verify all DNS records
dig ANY sagebrush.services
```

**Important Notes:**

1. **Keep CloudFlare Active**: Don't delete CloudFlare settings until propagation completes
2. **Backup DNS Records**: Export all CloudFlare DNS records before transfer
3. **Email Disruption**: Email may be disrupted during propagation if using CloudFlare email
4. **SSL Certificates**: Update SSL certificates to use AWS Certificate Manager
5. **Rollback**: Can revert to CloudFlare nameservers if issues occur

## Local Development with LocalStack

### Complete ECS + ALB + DNS Setup

Here's how to create a complete local development environment with nginx running
in ECS Fargate, accessible through an Application Load Balancer with custom DNS.

#### 1. Start LocalStack with DNS Support

```bash
# Stop any existing LocalStack instance
localstack stop

# Start LocalStack with DNS server enabled
localstack start --host-dns
```

The `--host-dns` flag enables LocalStack's DNS server, allowing you to resolve
custom domains locally without editing `/etc/hosts`.

#### 2. Set LocalStack Credentials

```bash
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"
```

#### 3. Create Infrastructure Stack

```bash
# 1. Create VPC (required foundation)
swift run AWS create-vpc \
  --region us-east-1 \
  --stack-name dev-vpc \
  --class-b 10

# 2. Create ALB with Route53 DNS
# Note: Create ALB before ECS to get the TargetGroupArn
swift run AWS create-alb \
  --region us-east-1 \
  --stack-name dev-alb \
  --vpc-stack dev-vpc \
  --ecs-stack dev-ecs \
  --domain-name www.sagebrush.services

# 3. Create ECS Cluster with Fargate nginx
# The ECS service will automatically register with the ALB target group
swift run AWS create-ecs \
  --region us-east-1 \
  --stack-name dev-ecs \
  --vpc-stack dev-vpc \
  --cluster-name dev-cluster
```

#### 4. Verify DNS Resolution

```bash
# Verify that the custom domain resolves via LocalStack DNS
dig @127.0.0.1 www.sagebrush.services

# Should return:
# www.sagebrush.services.  60  IN  A  127.0.0.1
```

#### 5. Check ECS Task and ALB Integration

```bash
# Verify ECS tasks are running
aws --endpoint-url=http://localhost.localstack.cloud:4566 \
  ecs list-tasks --cluster dev-cluster

# Verify targets are registered with ALB and healthy
aws --endpoint-url=http://localhost.localstack.cloud:4566 \
  elbv2 describe-target-health \
  --target-group-arn <target-group-arn-from-alb-output>

# Should show:
# {
#   "TargetHealthDescriptions": [
#     {
#       "Target": {
#         "Id": "192.168.x.x",
#         "Port": 80
#       },
#       "TargetHealth": {
#         "State": "healthy"
#       }
#     }
#   ]
# }
```

#### 6. Run Integration Tests

```bash
# Run the complete ALB integration test
swift test --filter ALBTests

# This test verifies:
# - VPC, ALB, and ECS stacks are created successfully
# - Application Load Balancer is active
# - Target Group is configured correctly
# - ECS tasks register as healthy targets
# - Route53 DNS is configured
```

### LocalStack Limitations

**What Works in LocalStack Community Edition:**

- ✅ CloudFormation stack creation and management
- ✅ ECS Fargate task definitions and services
- ✅ Application Load Balancer creation
- ✅ Target Group configuration and health checks
- ✅ Route53 hosted zone and DNS record creation
- ✅ DNS resolution via LocalStack DNS server (`dig @127.0.0.1`)
- ✅ ECS tasks register as healthy targets in ALB

**What Requires LocalStack Pro:**

- ❌ Direct HTTP access to ALB endpoints
- ❌ Full networking between ALB and ECS containers
- ❌ Cross-service network connectivity

**Workaround for Testing:**

While direct HTTP access isn't available in LocalStack Community, the integration
tests verify all components are correctly configured:

```bash
# The ALB test shows target registration:
✅ Targets registered with ALB:
   - Target: 192.168.65.254:41799
     State: healthy
```

This confirms that in production AWS, nginx would be accessible at your custom
domain.

## Example: Bootstrap Complete Infrastructure

### Local Development (LocalStack)

Here's how to bootstrap a complete local development environment:

```bash
# Start LocalStack first
localstack start

# Set test credentials (any value works with LocalStack)
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"

# 1. Create VPC
swift run AWS create-vpc \
  --region us-east-1 \
  --stack-name dev-vpc \
  --class-b 10

# 2. Create ECS Cluster
swift run AWS create-ecs \
  --region us-east-1 \
  --stack-name dev-ecs \
  --vpc-stack dev-vpc \
  --cluster-name dev-cluster

# 3. Create RDS Database
swift run AWS create-rds \
  --region us-east-1 \
  --stack-name dev-rds \
  --vpc-stack dev-vpc \
  --db-name development \
  --db-username postgres \
  --db-password "dev-password-123" \
  --min-capacity 0.5 \
  --max-capacity 1

# 4. Create S3 Buckets
swift run AWS create-s3 \
  --region us-east-1 \
  --stack-name dev-public-bucket \
  --bucket-name dev-public-assets \
  --public-access

swift run AWS create-s3 \
  --region us-east-1 \
  --stack-name dev-private-bucket \
  --bucket-name dev-private-uploads
```

### Production (Real AWS)

Here's how to bootstrap a production AWS environment:

```bash
# Set management account credentials (used for all accounts via AssumeRole)
export AWS_ACCESS_KEY_ID="your-management-account-access-key"
export AWS_SECRET_ACCESS_KEY="your-management-account-secret-key"

# 0. FIRST: Deploy IAM roles to all accounts (one-time setup)
# Deploy to Management account first
ENV=production swift run AWS create-iam --region us-west-2

# Then deploy to Production account
ENV=production swift run AWS create-iam \
  --account 978489150794 \
  --region us-west-2

# Repeat for other accounts (staging, housekeeping, neonlaw) as needed

# 1. Create VPC in Production Account
ENV=production swift run AWS create-vpc \
  --account 978489150794 \
  --region us-west-2 \
  --stack-name prod-vpc \
  --class-b 10

# 2. Create ECS Cluster in Production Account
ENV=production swift run AWS create-ecs \
  --account 978489150794 \
  --region us-west-2 \
  --stack-name prod-ecs \
  --vpc-stack prod-vpc \
  --cluster-name production-cluster

# 3. Create RDS Database in Production Account
ENV=production swift run AWS create-rds \
  --account 978489150794 \
  --region us-west-2 \
  --stack-name prod-rds \
  --vpc-stack prod-vpc \
  --db-name production \
  --db-username postgres \
  --db-password "$PROD_DB_PASSWORD" \
  --min-capacity 0.5 \
  --max-capacity 4

# 4. Create S3 Buckets in Production Account
ENV=production swift run AWS create-s3 \
  --account 978489150794 \
  --region us-west-2 \
  --stack-name prod-public-bucket \
  --bucket-name sagebrush-production-public-assets \
  --public-access

ENV=production swift run AWS create-s3 \
  --account 978489150794 \
  --region us-west-2 \
  --stack-name prod-private-bucket \
  --bucket-name sagebrush-production-private-uploads
```

### Staging Environment Example

```bash
# Use same credentials as production (AssumeRole into staging account)
export AWS_ACCESS_KEY_ID="your-management-account-access-key"
export AWS_SECRET_ACCESS_KEY="your-management-account-secret-key"

# 0. FIRST: Deploy IAM role to Staging account (one-time setup)
ENV=production swift run AWS create-iam \
  --account 889786867297 \
  --region us-west-2

# 1. Deploy to Staging Account (889786867297)
ENV=production swift run AWS create-vpc \
  --account 889786867297 \
  --region us-west-2 \
  --stack-name staging-vpc \
  --class-b 11

ENV=production swift run AWS create-ecs \
  --account 889786867297 \
  --region us-west-2 \
  --stack-name staging-ecs \
  --vpc-stack staging-vpc \
  --cluster-name staging-cluster
```

## Testing

Run the test suite to validate CloudFormation templates:

```bash
swift test
```

Tests verify:

- CloudFormation template validity (valid JSON)
- Required AWS resources are present
- Required outputs are exported
- Template structure is correct

## Development

### Project Structure

```text
Sources/
├── main.swift              # CLI entrypoint with commands
├── Stack.swift             # Stack protocol
├── AWSClient.swift         # AWS CloudFormation client wrapper
└── Stacks/
    ├── VPCStack.swift      # VPC CloudFormation template
    ├── ECSStack.swift      # ECS CloudFormation template
    ├── RDSStack.swift      # RDS CloudFormation template
    └── S3Stack.swift       # S3 CloudFormation template
Tests/
└── StackTests.swift        # Template validation tests
```

### Adding New Infrastructure Components

1. Create a new stack file in `Sources/Stacks/`
2. Implement the `Stack` protocol
3. Add a command in `main.swift`
4. Add tests in `Tests/StackTests.swift`

## Troubleshooting

### LocalStack Issues

If LocalStack commands fail:

1. Verify LocalStack is running: `localstack status`
2. Check LocalStack logs: `localstack logs`
3. Restart LocalStack: `localstack stop && localstack start`
4. Verify endpoint is accessible: `curl
  http://localhost.localstack.cloud:4566/_localstack/health`

### Authentication Issues

**For LocalStack (Development)**:

- Any credentials work with LocalStack
- Set test credentials: `export AWS_ACCESS_KEY_ID="test" AWS_SECRET_ACCESS_KEY="test"`

**For Production (with --account parameter)**:

If you see authentication or AssumeRole errors:

1. Verify base credentials are set:

   ```bash
   echo $AWS_ACCESS_KEY_ID
   echo $AWS_SECRET_ACCESS_KEY
   ```

2. Test that your base credentials can assume the role:

   ```bash
   aws sts assume-role \
     --role-arn arn:aws:iam::978489150794:role/SagebrushCLIRole \
     --role-session-name test
   ```

3. Verify the trust relationship on the target account's `SagebrushCLIRole`
   allows your Management account

4. Ensure the IAM user in the Management account has `sts:AssumeRole`
   permission

**For Legacy Profile-Based Authentication**:

If you see authentication errors with `--profile`:

1. Verify AWS CLI is configured: `aws configure list`
2. Test credentials: `aws sts get-caller-identity --profile your-profile`
3. Check profile exists: `cat ~/.aws/credentials`

### Stack Creation Failures

If stack creation fails:

1. Check CloudFormation console for detailed error messages
2. Verify VPC stack exists before creating dependent resources
3. Ensure IAM permissions are sufficient

### Region-Specific Issues

Some resources may not be available in all regions. Use regions with full
service support:

- `us-west-2` (Oregon)
- `us-east-2` (Ohio)

## Copyright and License

Copyright © 2025 Sagebrush Services LLC. All rights reserved.

This software and associated documentation files (the "Software") are the proprietary and confidential
property of Sagebrush Services LLC. This repository is private and will always remain private.

**Unauthorized copying, distribution, modification, public display, or public performance of this Software,
via any medium, is strictly prohibited.**

This Software is provided for internal use by Sagebrush Services LLC only.
