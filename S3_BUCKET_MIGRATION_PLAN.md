# S3 Bucket Migration Plan

**Date**: 2026-01-02
**Status**: PROPOSAL - Awaiting Approval

## Current State

### Buckets to Delete

#### Management Account (731099197338)

- `sagebrush-public` (78 objects, 17 MB) - **BACKUP REQUIRED**
- `sagebrush-private` (unknown contents) - **BACKUP REQUIRED**
- `sagebrush-mailroom-development` (0 objects)

#### Production Account (978489150794)

- `standards-lambda-artifacts-978489150794` (1 object, 256 bytes)

#### Staging Account (889786867297)

- `standards-lambda-artifacts-889786867297` (1 object, 263 bytes)

#### Housekeeping Account (374073887345)

- `sagebrush-housekeeping-lambda-code` (1 object, 40 MB) - **BACKUP REQUIRED**

#### NeonLaw Account (102186460229)

- `standards-lambda-artifacts-102186460229` (1 object, 256 bytes)

---

## Proposed New Buckets

### Naming Pattern

```
sagebrush-<account-id>-<uuid>
```

Example: `sagebrush-731099197338-a1b2c3d4e5f6`

### Tag Strategy

Every bucket will have these tags:

- `Name`: Short logical name (e.g., "mailroom", "email", "lambda-artifacts")
- `Purpose`: Detailed description of bucket usage
  (e.g., "Physical mail processing and virtual mailbox")
- `Environment`: Account environment (management/production/staging/housekeeping/neonlaw)
- `CostCenter`: For billing tracking (account name)
- `ManagedBy`: "Sagebrush-AWS-CLI"

**Example**:

```json
{
  "Name": "mailroom",
  "Purpose": "Physical mail processing, scans, and virtual mailbox documents",
  "Environment": "production",
  "CostCenter": "Production",
  "ManagedBy": "Sagebrush-AWS-CLI"
}
```

---

## New Bucket Inventory

### Management Account (731099197338)

**NO BUCKETS** - All deleted, not needed

### Production Account (978489150794)

| Bucket Name Pattern | Tag: Name | Tag: Purpose | Tag: CostCenter |
|---|---|---|---|
| `sagebrush-978489150794-<uuid>` | `lambda-artifacts` | Lambda deployment packages and build artifacts | `Production` |
| `sagebrush-978489150794-<uuid>` | `user-uploads` | Production user file uploads | `Production` |
| `sagebrush-978489150794-<uuid>` | `application-logs` | Application and Lambda logs | `Production` |
| `sagebrush-978489150794-<uuid>` | `mailroom` | Physical mail processing and virtual mailbox | `Production` |
| `sagebrush-978489150794-<uuid>` | `email` | Email processing and temporary message storage | `Production` |

### Staging Account (889786867297)

| Bucket Name Pattern | Tag: Name | Tag: Purpose | Tag: CostCenter |
|---|---|---|---|
| `sagebrush-889786867297-<uuid>` | `lambda-artifacts` | Lambda deployment packages and build artifacts | `Staging` |
| `sagebrush-889786867297-<uuid>` | `user-uploads` | Staging user file uploads for testing | `Staging` |
| `sagebrush-889786867297-<uuid>` | `application-logs` | Application and Lambda logs | `Staging` |
| `sagebrush-889786867297-<uuid>` | `mailroom` | Physical mail processing and virtual mailbox | `Staging` |
| `sagebrush-889786867297-<uuid>` | `email` | Email processing and temporary message storage | `Staging` |

### Housekeeping Account (374073887345)

| Bucket Name Pattern | Tag: Name | Tag: Purpose | Tag: CostCenter |
|---|---|---|---|
| `sagebrush-374073887345-<uuid>` | `lambda-code` | DailyBilling and housekeeping Lambda functions | `Housekeeping` |
| `sagebrush-374073887345-<uuid>` | `billing-reports` | Daily billing reports and cost data exports | `Housekeeping` |
| `sagebrush-374073887345-<uuid>` | `archive` | Cross-account backups and disaster recovery | `Housekeeping` |

### NeonLaw Account (102186460229)

| Bucket Name Pattern | Tag: Name | Tag: Purpose | Tag: CostCenter |
|---|---|---|---|
| `sagebrush-102186460229-<uuid>` | `lambda-artifacts` | Lambda deployment packages and build artifacts | `NeonLaw` |
| `sagebrush-102186460229-<uuid>` | `user-uploads` | NeonLaw user file uploads | `NeonLaw` |
| `sagebrush-102186460229-<uuid>` | `application-logs` | Application and Lambda logs | `NeonLaw` |
| `sagebrush-102186460229-<uuid>` | `email` | Email processing and temporary message storage | `NeonLaw` |

---

## Total Bucket Count

- **Management**: 0 buckets (all deleted)
- **Production**: 5 buckets
- **Staging**: 5 buckets
- **Housekeeping**: 3 buckets
- **NeonLaw**: 4 buckets

**TOTAL**: 17 buckets across 4 accounts

---

## Migration Steps

1. **Backup Phase**
   - Download `sagebrush-housekeeping-lambda-code` (40 MB) - DailyBilling Lambda
   - Management account buckets: NO BACKUP - will be deleted permanently

2. **Delete Phase**
   - Empty and delete all 3 buckets in Management account (731099197338)
   - Empty and delete `standards-lambda-artifacts-978489150794` in Production
   - Empty and delete `standards-lambda-artifacts-889786867297` in Staging
   - Empty and delete `sagebrush-housekeeping-lambda-code` in Housekeeping (after backup)
   - Empty and delete `standards-lambda-artifacts-102186460229` in NeonLaw

3. **Create Phase**
   - Create 17 new UID-based buckets with tags using Swift CloudFormation stacks
   - Generate a UUID for each bucket
   - Apply proper tags for logical naming

4. **Restore Phase**
   - Upload DailyBilling Lambda to new `lambda-code` bucket in Housekeeping account

5. **Update Phase**
   - Update DailyBilling Lambda CloudFormation stack with new bucket name
   - Update `DEPLOYED_RESOURCES.md`
   - Update environment variables in DailyBilling Lambda function

---

## Benefits

1. **Globally Unique Names** - No naming conflicts across regions/accounts
2. **Security Through Obscurity** - Harder to guess bucket names
3. **Logical Organization** - Query and reference by tags instead of hardcoded names
4. **Cost Tracking** - Granular cost allocation via `CostCenter` tags
5. **Immutable Infrastructure** - Easy to recreate buckets with new UUIDs
6. **Scalability** - Can add new buckets without name collision concerns

---

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Data loss during migration | Complete backups before deletion |
| Broken references after migration | Systematic update of all CloudFormation exports and environment variables |
| Bucket name dependencies in code | Use CloudFormation exports and SSM Parameter Store for bucket references |
| Cost during transition | Delete old buckets immediately after successful migration |

---

## User Decisions (Resolved)

1. ✅ **Bucket inventory approved** - 17 buckets across 4 accounts
2. ✅ **Management account** - Delete all buckets, no backups needed
3. ✅ **Production/Staging/NeonLaw** - Added `mailroom` bucket (physical mail processing)
4. ✅ **Production/Staging/NeonLaw** - Added `email` bucket (email processing)
5. ✅ **Housekeeping** - Renamed `backups` to `archive`
6. ✅ **Sagebrush Services** - Virtual mailbox service providing physical home/address for portfolio companies

## Outstanding Questions

1. **Additional tags?** (e.g., `Owner`, `Project`, `ComplianceLevel`) - Using defaults if not specified
2. **Proceed with deletion and creation?** Ready to execute migration plan?

---

## Next Steps (After Approval)

1. Create Swift CloudFormation stack for S3 bucket creation with UID + tags
2. Backup existing bucket contents
3. Execute deletion plan
4. Create new buckets
5. Restore data
6. Update all infrastructure references
7. Update documentation
