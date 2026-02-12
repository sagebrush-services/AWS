# CodeCommit Integration Roadmap

## Overview

This roadmap outlines the implementation of a GitHub → AWS CodeCommit mirroring system for Sagebrush and NeonLaw repositories. When code is pushed to GitHub, GitHub Actions will automatically push the same code to CodeCommit repositories in the appropriate AWS accounts.

## Repository Mappings

### Sagebrush Repositories (Both Staging & Production)

| Repository | GitHub URL | Staging CodeCommit | Production CodeCommit |
|------------|-----------|-------------------|----------------------|
| Sagebrush/Web | `git@github.com:sagebrush-services/Web.git` | `codecommit::us-west-2://sagebrush-web` (Account: 889786867297) | `codecommit::us-west-2://sagebrush-web` (Account: 978489150794) |
| Sagebrush/API | `git@github.com:sagebrush-services/API.git` | `codecommit::us-west-2://sagebrush-api` (Account: 889786867297) | `codecommit::us-west-2://sagebrush-api` (Account: 978489150794) |
| Sagebrush/Operations | `git@github.com:sagebrush-services/Operations.git` | `codecommit::us-west-2://sagebrush-operations` (Account: 889786867297) | `codecommit::us-west-2://sagebrush-operations` (Account: 978489150794) |

### NeonLaw Repositories (Production Only)

| Repository | GitHub URL | Production CodeCommit |
|------------|-----------|----------------------|
| NeonLaw/Web | `git@github.com:neon-law/Web.git` | `codecommit::us-west-2://neon-law-web` (Account: 102186460229) |
| NeonLaw/API | `git@github.com:neon-law/api.git` | `codecommit::us-west-2://neon-law-api` (Account: 102186460229) |
| NLF/Web | `git@github.com:neon-law-foundation/web.git` | `codecommit::us-west-2://nlf-web` (Account: 102186460229) |

## AWS Account Reference

- **Staging**: 889786867297 (`sagebrush-staging@shook.family`)
- **Production (Sagebrush)**: 978489150794 (`sagebrush-prod@shook.family`)
- **Production (NeonLaw)**: 102186460229 (`neon-law@shook.family`)

## Implementation Plan

### Phase 1: AWS Infrastructure Setup (Infrastructure as Code)

This implementation uses the **Sagebrush AWS CLI** (Swift-based IaC) instead of manual AWS CLI commands. All infrastructure is defined in CloudFormation templates and managed through the `GitHubMirrorStack`.

#### 1.1 Understanding the GitHubMirrorStack

The `GitHubMirrorStack` creates a complete GitHub mirroring solution in a single CloudFormation stack:

**Resources Created:**
1. **CodeCommit Repository** - Git repository for mirrored code
2. **IAM User** - Dedicated user for GitHub Actions (e.g., `github-sagebrush-web-staging`)
3. **IAM Policy** - Least privilege policy scoped to only this repository
4. **Policy Attachment** - Attaches policy to user
5. **Access Key** - Generates credentials for GitHub Actions

**Benefits:**
- Version-controlled infrastructure (Swift code in git)
- Consistent deployment across all repositories
- Single command creates everything
- Easy cleanup (delete stack removes all resources)
- Type-safe CloudFormation templates

#### 1.2 Deploy GitHub Mirror Stacks

**In Staging Account (889786867297):**
```bash
cd ~/Trifecta/Sagebrush/AWS

# Sagebrush Web staging
ENV=production swift run AWS create-github-mirror \
  --account staging \
  --region us-west-2 \
  --stack-name sagebrush-web-staging-mirror \
  --repository-name sagebrush-web \
  --environment staging

# Sagebrush API staging
ENV=production swift run AWS create-github-mirror \
  --account staging \
  --region us-west-2 \
  --stack-name sagebrush-api-staging-mirror \
  --repository-name sagebrush-api \
  --environment staging

# Sagebrush Operations staging
ENV=production swift run AWS create-github-mirror \
  --account staging \
  --region us-west-2 \
  --stack-name sagebrush-operations-staging-mirror \
  --repository-name sagebrush-operations \
  --environment staging
```

**In Production Account (978489150794):**
```bash
# Sagebrush Web production
ENV=production swift run AWS create-github-mirror \
  --account production \
  --region us-west-2 \
  --stack-name sagebrush-web-prod-mirror \
  --repository-name sagebrush-web \
  --environment production

# Sagebrush API production
ENV=production swift run AWS create-github-mirror \
  --account production \
  --region us-west-2 \
  --stack-name sagebrush-api-prod-mirror \
  --repository-name sagebrush-api \
  --environment production

# Sagebrush Operations production
ENV=production swift run AWS create-github-mirror \
  --account production \
  --region us-west-2 \
  --stack-name sagebrush-operations-prod-mirror \
  --repository-name sagebrush-operations \
  --environment production
```

**In NeonLaw Production Account (102186460229):**
```bash
# NeonLaw Web production
ENV=production swift run AWS create-github-mirror \
  --account neonlaw \
  --region us-west-2 \
  --stack-name neon-law-web-prod-mirror \
  --repository-name neon-law-web \
  --environment production

# NeonLaw API production
ENV=production swift run AWS create-github-mirror \
  --account neonlaw \
  --region us-west-2 \
  --stack-name neon-law-api-prod-mirror \
  --repository-name neon-law-api \
  --environment production

# NLF Web production
ENV=production swift run AWS create-github-mirror \
  --account neonlaw \
  --region us-west-2 \
  --stack-name nlf-web-prod-mirror \
  --repository-name nlf-web \
  --environment production
```

#### 1.3 Collect Access Keys from CloudFormation Outputs

After each stack is created, retrieve the access keys from CloudFormation outputs:

```bash
# Example for Sagebrush Web Staging
aws cloudformation describe-stacks \
  --region us-west-2 \
  --stack-name sagebrush-web-staging-mirror \
  --query 'Stacks[0].Outputs' \
  --output table
```

**Stack Outputs Include:**
- `RepositoryName` - CodeCommit repository name
- `RepositoryArn` - Full ARN of the repository
- `CloneUrlHttp` - HTTP clone URL
- `CloneUrlSsh` - SSH clone URL
- `IAMUserName` - Created IAM user name
- `AccessKeyId` - AWS Access Key ID for GitHub Actions
- `SecretAccessKey` - AWS Secret Access Key (marked as NoEcho, retrieve from Secrets Manager or stack outputs)

**Alternative: Using AWS CLI to get specific output:**

```bash
# Get Access Key ID
aws cloudformation describe-stacks \
  --region us-west-2 \
  --stack-name sagebrush-web-staging-mirror \
  --query 'Stacks[0].Outputs[?OutputKey==`AccessKeyId`].OutputValue' \
  --output text

# Get Secret Access Key (if not NoEcho)
aws cloudformation describe-stacks \
  --region us-west-2 \
  --stack-name sagebrush-web-staging-mirror \
  --query 'Stacks[0].Outputs[?OutputKey==`SecretAccessKey`].OutputValue' \
  --output text
```

**Security Note:** The `SecretAccessKey` is marked as `NoEcho` in CloudFormation for security. You'll only see it once when the stack is created. Store it securely immediately.

### Phase 2: GitHub Configuration

#### 2.1 GitHub Secrets to Create

**For sagebrush-services/Web:**
- `AWS_STAGING_ACCESS_KEY_ID` - Access key for github-sagebrush-web-staging
- `AWS_STAGING_SECRET_ACCESS_KEY` - Secret for github-sagebrush-web-staging
- `AWS_PROD_ACCESS_KEY_ID` - Access key for github-sagebrush-web-prod
- `AWS_PROD_SECRET_ACCESS_KEY` - Secret for github-sagebrush-web-prod
- `AWS_REGION` - `us-west-2` (can be shared)

**For sagebrush-services/API:**
- `AWS_STAGING_ACCESS_KEY_ID` - Access key for github-sagebrush-api-staging
- `AWS_STAGING_SECRET_ACCESS_KEY` - Secret for github-sagebrush-api-staging
- `AWS_PROD_ACCESS_KEY_ID` - Access key for github-sagebrush-api-prod
- `AWS_PROD_SECRET_ACCESS_KEY` - Secret for github-sagebrush-api-prod
- `AWS_REGION` - `us-west-2`

**For sagebrush-services/Operations:**
- `AWS_STAGING_ACCESS_KEY_ID` - Access key for github-sagebrush-operations-staging
- `AWS_STAGING_SECRET_ACCESS_KEY` - Secret for github-sagebrush-operations-staging
- `AWS_PROD_ACCESS_KEY_ID` - Access key for github-sagebrush-operations-prod
- `AWS_PROD_SECRET_ACCESS_KEY` - Secret for github-sagebrush-operations-prod
- `AWS_REGION` - `us-west-2`

**For neon-law/Web:**
- `AWS_PROD_ACCESS_KEY_ID` - Access key for github-neon-law-web-prod
- `AWS_PROD_SECRET_ACCESS_KEY` - Secret for github-neon-law-web-prod
- `AWS_REGION` - `us-west-2`

**For neon-law/api:**
- `AWS_PROD_ACCESS_KEY_ID` - Access key for github-neon-law-api-prod
- `AWS_PROD_SECRET_ACCESS_KEY` - Secret for github-neon-law-api-prod
- `AWS_REGION` - `us-west-2`

**For neon-law-foundation/web:**
- `AWS_PROD_ACCESS_KEY_ID` - Access key for github-nlf-web-prod
- `AWS_PROD_SECRET_ACCESS_KEY` - Secret for github-nlf-web-prod
- `AWS_REGION` - `us-west-2`

#### 2.2 GitHub Actions Workflows

**Workflow Location:** `.github/workflows/codecommit-mirror.yml`

**For Sagebrush Repositories (Web, API, Operations):**

```yaml
name: Mirror to AWS CodeCommit

on:
  push:
    branches:
      - main
      - develop
      - 'release/**'
      - 'hotfix/**'

jobs:
  mirror-to-staging:
    name: Mirror to CodeCommit Staging
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for proper mirroring

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_STAGING_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_STAGING_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Install git-remote-codecommit
        run: pip install git-remote-codecommit

      - name: Push to CodeCommit Staging
        env:
          REPO_NAME: sagebrush-web  # Change per repository: sagebrush-web, sagebrush-api, sagebrush-operations
        run: |
          git remote add codecommit-staging codecommit::us-west-2://${REPO_NAME}
          git push codecommit-staging --all --force
          git push codecommit-staging --tags --force

  mirror-to-production:
    name: Mirror to CodeCommit Production
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'  # Only mirror main to production
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_PROD_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_PROD_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Install git-remote-codecommit
        run: pip install git-remote-codecommit

      - name: Push to CodeCommit Production
        env:
          REPO_NAME: sagebrush-web  # Change per repository: sagebrush-web, sagebrush-api, sagebrush-operations
        run: |
          git remote add codecommit-prod codecommit::us-west-2://${REPO_NAME}
          git push codecommit-prod --all --force
          git push codecommit-prod --tags --force
```

**For NeonLaw Repositories (Web, API, and NLF/Web) - Production Only:**

```yaml
name: Mirror to AWS CodeCommit

on:
  push:
    branches:
      - main

jobs:
  mirror-to-production:
    name: Mirror to CodeCommit Production
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_PROD_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_PROD_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Install git-remote-codecommit
        run: pip install git-remote-codecommit

      - name: Push to CodeCommit Production
        env:
          REPO_NAME: neon-law-web  # Change per repository: neon-law-web, neon-law-api, nlf-web
        run: |
          git remote add codecommit-prod codecommit::us-west-2://${REPO_NAME}
          git push codecommit-prod --all --force
          git push codecommit-prod --tags --force
```

## Security Considerations

### Least Privilege Implementation

1. **Separate IAM users per repository**: Each GitHub repository has its own dedicated IAM user
2. **Minimal permissions**: Users can only GitPush/GitPull to their specific CodeCommit repository
3. **Resource-specific policies**: Each policy is scoped to exactly one CodeCommit repository ARN
4. **No console access**: IAM users are programmatic-only (no password, no console access)
5. **Access key rotation**: Plan to rotate access keys quarterly

### Additional Security Measures

1. **Branch protection**: Consider limiting production mirrors to `main` branch only
2. **Approval gates**: For production pushes, consider requiring manual approval in GitHub Actions
3. **Audit logging**: Enable CloudTrail for all CodeCommit repositories
4. **Secrets management**: Use GitHub's encrypted secrets (never commit credentials)

## Testing Strategy

### Manual Testing Steps

1. Create test branch in GitHub repository
2. Push test branch to GitHub
3. Verify GitHub Actions workflow runs successfully
4. Verify branch appears in CodeCommit staging
5. Merge to main
6. Verify main is mirrored to CodeCommit production

### Validation Checklist

- [ ] All CodeCommit repositories created
- [ ] All IAM users created
- [ ] All IAM policies created and attached
- [ ] All access keys generated and stored securely
- [ ] All GitHub secrets configured
- [ ] All GitHub Actions workflows created
- [ ] Test push to non-main branch → appears in staging only
- [ ] Test push to main branch → appears in both staging and production
- [ ] Verify no unauthorized access (try accessing wrong repo with credentials)

## Rollout Order

1. **Start with Sagebrush/Operations** (business operations, lowest risk)
2. **Then Sagebrush/API** (backend service)
3. **Then Sagebrush/Web** (frontend application)
4. **Then NeonLaw/Web** (separate organization, different account)
5. **Then NeonLaw/API** (NeonLaw backend service)
6. **Finally NLF/Web** (foundation website)

## Future Considerations

1. **Bi-directional sync**: Currently one-way (GitHub → CodeCommit)
2. **Automation**: Consider using Terraform/CloudFormation for IAM setup
3. **Monitoring**: Set up CloudWatch alerts for failed pushes
4. **OIDC**: Consider GitHub OIDC provider instead of static credentials (more secure)
5. **Additional repositories**: Other Trifecta repositories may be added in the future

## Alternative: GitHub OIDC (Recommended Enhancement)

Instead of long-lived access keys, GitHub supports OIDC federation:

**Benefits:**
- No static credentials to manage
- Automatic credential rotation
- More secure (temporary credentials only)
- Easier to audit

**Implementation would require:**
1. Create OIDC identity provider in each AWS account
2. Create IAM roles (instead of users) with trust policy for GitHub
3. Modify workflows to assume roles instead of using access keys

This is recommended for Phase 2 after initial implementation is working.
