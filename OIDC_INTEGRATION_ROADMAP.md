# OIDC Integration Roadmap

Comprehensive plan for implementing single OIDC authentication for Neon Law Matters API and CodeCommit access.

## Overview

**Goal:** Replace dual authentication (OIDC for API + AWS IAM for Git) with single OIDC authentication system.

**Authentication Flow:**

```
User → auth.neonlaw.com (OIDC) → Access Token
                                       ↓
                    ┌──────────────────┴──────────────────┐
                    ↓                                      ↓
            api.neonlaw.com                    AWS STS AssumeRoleWithWebIdentity
            (Bearer Token)                                 ↓
                                                  Temporary AWS Credentials
                                                           ↓
                                                   CodeCommit Operations
```

## Current State

### Existing Infrastructure

1. **IAMStack.swift** - Contains OIDC provider management permissions
   - Lines 425-431: Already includes OIDC provider creation/management permissions
   - Confirms infrastructure capability for OIDC providers

2. **GitHubOIDCStack.swift** - Reference implementation for OIDC federation
   - Shows pattern for AWS::IAM::OIDCProvider creation
   - Demonstrates AssumeRoleWithWebIdentity trust policy
   - Example thumbprint configuration

3. **CodeCommitStack.swift** - Basic repository creation
   - Simple repository creation without access controls
   - Needs integration with OIDC-based access policies

### Missing Components

1. **Neon Law OIDC Provider** - IAM OIDC provider for `auth.neonlaw.com`
2. **CodeCommit Access Role** - IAM role assumable via OIDC web identity
3. **Matters API Integration** - Backend API endpoint at `api.neonlaw.com/matters`

## Implementation Phases

### Phase 1: Infrastructure as Code - New Stacks

#### 1.1 Create NeonLawOIDCStack.swift

**Location:** `~/Trifecta/Sagebrush/AWS/Sources/Stacks/NeonLawOIDCStack.swift`

**Purpose:** Create IAM OIDC provider for `auth.neonlaw.com` and CodeCommit access role

**Resources to Create:**

- `AWS::IAM::OIDCProvider` for `https://auth.neonlaw.com`
- `AWS::IAM::Role` named `NeonLawCodeCommitAccess`
- Inline policy for CodeCommit git operations

**Key Configuration:**

```swift
// OIDC Provider
- URL: "https://auth.neonlaw.com"
- ClientIdList: ["neonlaw-matters-client"]
- ThumbprintList: [<certificate-thumbprint>] // Obtain from auth.neonlaw.com

// IAM Role Trust Policy
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::731099197338:oidc-provider/auth.neonlaw.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "auth.neonlaw.com:aud": "neonlaw-matters-client"
    }
  }
}

// IAM Role Permissions
{
  "Effect": "Allow",
  "Action": [
    "codecommit:GitPull",
    "codecommit:GitPush",
    "codecommit:ListRepositories",
    "codecommit:GetRepository",
    "codecommit:GetBranch",
    "codecommit:ListBranches",
    "codecommit:CreateBranch",
    "codecommit:GetCommit",
    "codecommit:GetDifferences"
  ],
  "Resource": "arn:aws:codecommit:us-west-2:731099197338:*"
}
```

**Parameters:**

- `OIDCProviderThumbprint` - SSL certificate thumbprint for auth.neonlaw.com
- `OIDCClientId` - Client ID for the Neon Law application (default: `neonlaw-matters-client`)
- `OIDCAudience` - Expected audience claim in OIDC token

**Outputs:**

- `OIDCProviderArn` - ARN of the OIDC provider
- `CodeCommitRoleArn` - ARN of the role (used in client setup)
- `CodeCommitRoleName` - Name of the role

**Implementation Template:**

```swift
import Foundation

/// CloudFormation stack for Neon Law OIDC provider and CodeCommit access role
struct NeonLawOIDCStack: Stack {
    var templateBody: String {
        """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "Neon Law OIDC provider for single authentication system",
          "Parameters": {
            "OIDCProviderThumbprint": {
              "Type": "String",
              "Description": "SHA-1 thumbprint of auth.neonlaw.com SSL certificate"
            },
            "OIDCClientId": {
              "Type": "String",
              "Description": "OIDC client ID",
              "Default": "neonlaw-matters-client"
            }
          },
          "Resources": {
            "NeonLawOIDCProvider": {
              "Type": "AWS::IAM::OIDCProvider",
              "Properties": {
                "Url": "https://auth.neonlaw.com",
                "ClientIdList": [{ "Ref": "OIDCClientId" }],
                "ThumbprintList": [{ "Ref": "OIDCProviderThumbprint" }],
                "Tags": [{"Key": "Name", "Value": "NeonLawOIDC"}]
              }
            },
            "NeonLawCodeCommitAccessRole": {
              "Type": "AWS::IAM::Role",
              "Properties": {
                "RoleName": "NeonLawCodeCommitAccess",
                "Description": "Role for Neon Law users to access CodeCommit via OIDC",
                "AssumeRolePolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [{
                    "Effect": "Allow",
                    "Principal": {
                      "Federated": { "Ref": "NeonLawOIDCProvider" }
                    },
                    "Action": "sts:AssumeRoleWithWebIdentity",
                    "Condition": {
                      "StringEquals": {
                        "auth.neonlaw.com:aud": { "Ref": "OIDCClientId" }
                      }
                    }
                  }]
                },
                "Policies": [{
                  "PolicyName": "CodeCommitAccess",
                  "PolicyDocument": {
                    "Version": "2012-10-17",
                    "Statement": [{
                      "Effect": "Allow",
                      "Action": [
                        "codecommit:GitPull",
                        "codecommit:GitPush",
                        "codecommit:ListRepositories",
                        "codecommit:GetRepository"
                      ],
                      "Resource": "arn:aws:codecommit:us-west-2:731099197338:*"
                    }]
                  }
                }]
              }
            }
          },
          "Outputs": {
            "OIDCProviderArn": {
              "Value": { "Ref": "NeonLawOIDCProvider" },
              "Export": { "Name": { "Fn::Sub": "${AWS::StackName}-OIDCProviderArn" }}
            },
            "CodeCommitRoleArn": {
              "Value": { "Fn::GetAtt": ["NeonLawCodeCommitAccessRole", "Arn"] },
              "Export": { "Name": { "Fn::Sub": "${AWS::StackName}-RoleArn" }}
            }
          }
        }
        """
    }
}
```

#### 1.2 Update main.swift Command Structure

**Location:** `~/Trifecta/Sagebrush/AWS/Sources/main.swift`

**Changes:**

- Add `CreateNeonLawOIDC` command
- Register `NeonLawOIDCStack` in available stacks

```swift
struct CreateNeonLawOIDC: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-neonlaw-oidc",
        abstract: "Create Neon Law OIDC provider and CodeCommit access role"
    )

    @Option(help: "The name of the CloudFormation stack")
    var stackName: String = "NeonLawOIDC"

    @Option(help: "SSL certificate thumbprint for auth.neonlaw.com")
    var thumbprint: String

    @Option(help: "OIDC client ID")
    var clientId: String = "neonlaw-matters-client"

    func run() async throws {
        let stack = NeonLawOIDCStack()
        let parameters: [String: String] = [
            "OIDCProviderThumbprint": thumbprint,
            "OIDCClientId": clientId
        ]
        try await stack.deploy(stackName: stackName, parameters: parameters)
    }
}
```

### Phase 2: Backend API Development

#### 2.1 Matters API Endpoint

**Location:** Create new Lambda function or ECS service endpoint

**Endpoint:** `GET https://api.neonlaw.com/matters`

**Authentication:**

- Validate OIDC Bearer token from `Authorization` header
- Verify token signature against `auth.neonlaw.com` JWKS
- Extract user identity from token claims

**Response Logic:**

1. Parse and validate OIDC token
2. Extract user email/sub claim
3. Query database/IAM for user's accessible matters
4. Return list of CodeCommit repositories with names and URLs

**Database Schema (if using RDS):**

```sql
CREATE TABLE matter_permissions (
    id SERIAL PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL,
    matter_name VARCHAR(100) NOT NULL,
    repository_arn VARCHAR(255) NOT NULL,
    permissions VARCHAR(50)[] DEFAULT ARRAY['read', 'write'],
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_email, matter_name)
);

CREATE INDEX idx_matter_permissions_user ON matter_permissions(user_email);
```

**Implementation Options:**

**Option A: Lambda Function**

- Create `MattersAPILambdaStack.swift`
- Lambda validates OIDC token
- Queries DynamoDB/RDS for user permissions
- Returns filtered repository list

**Option B: ECS Service**

- Add `/matters` endpoint to existing ECS API service
- Integrate OIDC validation middleware
- Reuse existing database connections

#### 2.2 OIDC Token Validation Library

**Create:** Shared token validation module

**Responsibilities:**

- Fetch JWKS from `https://auth.neonlaw.com/.well-known/jwks.json`
- Verify token signature
- Validate claims (iss, aud, exp)
- Extract user identity

**Integration:** Used by both Matters API and any other OIDC-protected endpoints

### Phase 3: Deployment Steps

#### 3.1 Obtain OIDC Provider Thumbprint

```bash
# Get certificate thumbprint for auth.neonlaw.com
echo | openssl s_client -servername auth.neonlaw.com \
  -connect auth.neonlaw.com:443 2>/dev/null | \
  openssl x509 -fingerprint -sha1 -noout | \
  cut -d'=' -f2 | tr -d ':'
```

#### 3.2 Deploy OIDC Infrastructure

```bash
cd ~/Trifecta/Sagebrush/AWS

# Build Swift CLI
swift build -c release

# Deploy OIDC stack
.build/release/SagebrushAWS create-neonlaw-oidc \
  --stack-name NeonLawOIDC \
  --thumbprint <thumbprint-from-3.1> \
  --client-id neonlaw-matters-client
```

#### 3.3 Verify IAM Resources

```bash
# Verify OIDC provider created
aws iam list-open-id-connect-providers

# Verify role created
aws iam get-role --role-name NeonLawCodeCommitAccess

# Get role ARN for client configuration
aws iam get-role --role-name NeonLawCodeCommitAccess \
  --query 'Role.Arn' --output text
```

#### 3.4 Deploy Matters API

```bash
# Deploy Lambda or update ECS service
# (Specific commands depend on chosen implementation)
```

#### 3.5 Test End-to-End Flow

```bash
# 1. Obtain OIDC token from auth.neonlaw.com
# (Manual login or automated token retrieval)
export NEON_LAW_TOKEN="<oidc-access-token>"

# 2. Test Matters API
curl -H "Authorization: Bearer $NEON_LAW_TOKEN" \
  https://api.neonlaw.com/matters

# 3. Configure git-remote-codecommit
pip install git-remote-codecommit
mkdir -p ~/.neonlaw
echo "$NEON_LAW_TOKEN" > ~/.neonlaw/token
chmod 600 ~/.neonlaw/token

# 4. Configure AWS profile
cat >> ~/.aws/config <<EOF
[profile neonlaw]
role_arn = arn:aws:iam::731099197338:role/NeonLawCodeCommitAccess
web_identity_token_file = ~/.neonlaw/token
role_session_name = neonlaw-user
region = us-west-2
EOF

# 5. Test CodeCommit cloning
git clone codecommit://neonlaw@<repository-name> ~/test-clone
```

### Phase 4: Client Updates (Already Completed)

✅ **Standards Repository Documentation:**

- API.md - Updated to single OIDC authentication
- setup.sh - Configured for git-remote-codecommit with OIDC
- CLAUDE.md - Documents single OIDC auth system
- README.md - Updated authentication references

## Security Considerations

### 1. OIDC Token Validation

**Requirements:**

- Verify token signature using JWKS from `https://auth.neonlaw.com/.well-known/jwks.json`
- Validate issuer claim: `"iss": "https://auth.neonlaw.com"`
- Validate audience claim: `"aud": "neonlaw-matters-client"`
- Check expiration: `exp > current_time`
- Validate not-before: `nbf <= current_time`

**Implementation:**

```python
# Example Python validation (for Lambda)
import jwt
import requests
from functools import lru_cache

@lru_cache(maxsize=1)
def get_jwks():
    return requests.get("https://auth.neonlaw.com/.well-known/jwks.json").json()

def validate_token(token):
    jwks = get_jwks()
    header = jwt.get_unverified_header(token)
    key = next(k for k in jwks["keys"] if k["kid"] == header["kid"])

    return jwt.decode(
        token,
        key=jwt.algorithms.RSAAlgorithm.from_jwk(key),
        algorithms=["RS256"],
        audience="neonlaw-matters-client",
        issuer="https://auth.neonlaw.com"
    )
```

### 2. Least Privilege Access

**CodeCommit Role Permissions:**

- Grant only necessary CodeCommit operations
- Use resource-level permissions when possible
- Consider matter-specific access (future enhancement)

**Current Scope:** All repositories in account 731099197338
**Future Enhancement:** Per-repository access based on user claims

### 3. Token Rotation

**Client-Side:**

- OIDC tokens expire (typically 1 hour)
- git-remote-codecommit automatically requests new AWS credentials
- User must refresh OIDC token when expired

**Recommendations:**

- Document token refresh flow
- Consider refresh token support in auth.neonlaw.com
- Implement token caching with expiration checks

### 4. Audit Logging

**CloudTrail Events to Monitor:**

- `AssumeRoleWithWebIdentity` calls
- CodeCommit Git operations
- Matters API access

**Implementation:**

```bash
# Enable CloudTrail for IAM and CodeCommit events
# Already enabled in standard AWS setup
```

## Rollback Plan

### If Issues Arise

1. **Keep Existing IAM User Credentials:**
   - Maintain parallel access during transition
   - Remove only after 30 days of successful OIDC operation

2. **Feature Flag in setup.sh:**
   - Already implemented: Falls back to standard git URLs if git-remote-codecommit unavailable
   - Maintains compatibility with existing workflows

3. **Stack Deletion:**

```bash
# Remove OIDC infrastructure if needed
aws cloudformation delete-stack --stack-name NeonLawOIDC

# Verify deletion
aws cloudformation wait stack-delete-complete --stack-name NeonLawOIDC
```

## Success Criteria

- [ ] OIDC provider created in IAM for `auth.neonlaw.com`
- [ ] `NeonLawCodeCommitAccess` role created with proper trust policy
- [ ] Matters API endpoint deployed and responding to OIDC tokens
- [ ] Users can obtain token from `auth.neonlaw.com`
- [ ] Users can clone/push to CodeCommit using git-remote-codecommit
- [ ] Documentation updated (✅ already complete)
- [ ] No IAM user credentials required for git operations
- [ ] Audit logging captures OIDC authentication events

## Timeline Estimate

| Phase | Tasks | Estimated Time |
|-------|-------|----------------|
| Phase 1 | Create NeonLawOIDCStack.swift, update main.swift | 2 hours |
| Phase 2 | Implement Matters API endpoint and token validation | 4 hours |
| Phase 3 | Deploy and configure infrastructure | 2 hours |
| Phase 4 | Documentation updates | ✅ Complete |
| **Total** | | **8 hours** |

## Dependencies

1. **auth.neonlaw.com OIDC provider must be operational**
   - Must support standard OIDC discovery (`/.well-known/openid-configuration`)
   - Must provide JWKS endpoint (`/.well-known/jwks.json`)
   - Must issue tokens with appropriate claims

2. **API infrastructure**
   - Lambda/ECS service for Matters API
   - Database for user-matter permissions (or IAM-based approach)

3. **Client tooling**
   - git-remote-codecommit (Python package)
   - AWS CLI configured

## Open Questions

1. **User-Matter Mapping:**
   - How is the relationship between users and matters stored?
   - Database-driven or derived from IAM/OIDC claims?

2. **Token Claims:**
   - What user identifier is in the OIDC token (`sub`, `email`, custom claim)?
   - Are matter permissions embedded in token or queried separately?

3. **auth.neonlaw.com Provider:**
   - Is this already deployed?
   - What's the OIDC configuration (client IDs, scopes, etc.)?
   - Token lifetime and refresh token support?

## Next Steps

1. **Obtain OIDC Provider Details:**
   - Get auth.neonlaw.com SSL certificate thumbprint
   - Confirm OIDC client ID and audience values
   - Verify OIDC discovery endpoint accessibility

2. **Implement NeonLawOIDCStack.swift:**
   - Create Swift file following GitHubOIDCStack.swift pattern
   - Add command to main.swift
   - Test CloudFormation template generation

3. **Deploy OIDC Infrastructure:**
   - Run deployment command
   - Verify resources in AWS Console
   - Document role ARN for client use

4. **Implement Matters API:**
   - Choose Lambda vs ECS approach
   - Implement OIDC validation
   - Deploy and test endpoint

5. **End-to-End Testing:**
   - Authenticate via auth.neonlaw.com
   - Call Matters API
   - Clone CodeCommit repository
   - Verify git push operations

## References

- [AWS OIDC Identity Providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [AssumeRoleWithWebIdentity](https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithWebIdentity.html)
- [CodeCommit with Temporary Credentials](https://docs.aws.amazon.com/codecommit/latest/userguide/temporary-access.html)
- [git-remote-codecommit](https://docs.aws.amazon.com/codecommit/latest/userguide/setting-up-git-remote-codecommit.html)
- Existing Implementation: `Sources/Stacks/GitHubOIDCStack.swift`
