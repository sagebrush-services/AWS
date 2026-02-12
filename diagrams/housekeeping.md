# Housekeeping Account Architecture (374073887345)

The Housekeeping account provides operational tooling, scheduled maintenance tasks, log aggregation, and
cross-account monitoring for Staging and Production environments.

## Architecture Diagram

```mermaid
graph TB
    subgraph Housekeeping["Housekeeping Account (374073887345)"]
        subgraph EventBridge["EventBridge"]
            EB_RULE_5MIN["EventBridge Rule<br/>rate(5 minutes)"]
            EB_RULE_HOURLY["EventBridge Rule<br/>rate(1 hour)"]
            EB_RULE_DAILY["EventBridge Rule<br/>cron(0 0 * * ? *)"]
        end

        subgraph Lambda["Lambda Functions"]
            LAMBDA_LOG_AGGREGATOR["Log Aggregator<br/>ARM64/Graviton"]
            LAMBDA_BACKUP["Backup Orchestrator<br/>ARM64/Graviton"]
            LAMBDA_CLEANUP["Cleanup Task<br/>ARM64/Graviton"]
        end

        subgraph Storage["S3 Storage"]
            ICEBERG["Iceberg S3 Bucket<br/>Long-term Log Archive"]
            GLACIER["→ Glacier (90 days)"]
            DEEP_ARCHIVE["→ Deep Archive (1 year)"]
        end

        subgraph DNS["Route53"]
            R53_ZONE["Hosted Zone<br/>ops.sagebrush.services"]
        end

        subgraph IAM["IAM Cross-Account Roles"]
            ROLE_STAGING["AssumeRole:<br/>StagingReadRole"]
            ROLE_PROD["AssumeRole:<br/>ProductionReadRole"]
        end

        subgraph Logs["CloudWatch Logs"]
            CW_LOGS["Log Groups<br/>(7-day retention)"]
        end
    end

    subgraph Staging["Staging Account (889786867297)"]
        STAGING_S3["S3 Buckets"]
        STAGING_RDS["Aurora Postgres<br/>Serverless v2"]
        STAGING_ROLE["IAM Role:<br/>StagingReadRole"]
    end

    subgraph Production["Production Account (978489150794)"]
        PROD_S3["S3 Buckets"]
        PROD_RDS["Aurora Postgres<br/>Serverless v2"]
        PROD_ROLE["IAM Role:<br/>ProductionReadRole"]
    end

    subgraph Management["Management Account (731099197338)"]
        MGMT_R53["Route53<br/>DNS Delegation"]
    end

    %% EventBridge to Lambda triggers
    EB_RULE_5MIN -->|Trigger| LAMBDA_CLEANUP
    EB_RULE_HOURLY -->|Trigger| LAMBDA_LOG_AGGREGATOR
    EB_RULE_DAILY -->|Trigger| LAMBDA_BACKUP

    %% Lambda to S3 data flow
    LAMBDA_LOG_AGGREGATOR -->|Write logs| ICEBERG
    LAMBDA_BACKUP -->|Write backups| ICEBERG
    LAMBDA_CLEANUP -->|Write logs| CW_LOGS

    %% S3 Lifecycle transitions
    ICEBERG -->|90 days| GLACIER
    GLACIER -->|1 year| DEEP_ARCHIVE

    %% Cross-account access from Lambda
    LAMBDA_LOG_AGGREGATOR -->|AssumeRole| ROLE_STAGING
    LAMBDA_LOG_AGGREGATOR -->|AssumeRole| ROLE_PROD
    LAMBDA_BACKUP -->|AssumeRole| ROLE_STAGING
    LAMBDA_BACKUP -->|AssumeRole| ROLE_PROD

    %% Cross-account IAM role assumptions
    ROLE_STAGING -.->|STS AssumeRole| STAGING_ROLE
    ROLE_PROD -.->|STS AssumeRole| PROD_ROLE

    %% Cross-account data access
    STAGING_ROLE -->|Read| STAGING_S3
    STAGING_ROLE -->|Read| STAGING_RDS
    PROD_ROLE -->|Read| PROD_S3
    PROD_ROLE -->|Read| PROD_RDS

    %% DNS delegation
    MGMT_R53 -.->|Delegate zone| R53_ZONE

    %% Lambda to CloudWatch Logs
    LAMBDA_LOG_AGGREGATOR -->|Write logs| CW_LOGS
    LAMBDA_BACKUP -->|Write logs| CW_LOGS

    classDef eventbridge fill:#FF4F8B,stroke:#E83E7B,color:#fff
    classDef lambda fill:#FF9900,stroke:#E88500,color:#fff
    classDef s3 fill:#569A31,stroke:#478521,color:#fff
    classDef glacier fill:#1E5B8C,stroke:#0E4B7C,color:#fff
    classDef route53 fill:#8C4FFF,stroke:#7B3FEF,color:#fff
    classDef iam fill:#DD344C,stroke:#CC2340,color:#fff
    classDef logs fill:#4B612C,stroke:#3B512C,color:#fff
    classDef account fill:#232F3E,stroke:#1A252F,color:#fff

    class EB_RULE_5MIN,EB_RULE_HOURLY,EB_RULE_DAILY eventbridge
    class LAMBDA_LOG_AGGREGATOR,LAMBDA_BACKUP,LAMBDA_CLEANUP lambda
    class ICEBERG s3
    class GLACIER,DEEP_ARCHIVE glacier
    class R53_ZONE,MGMT_R53 route53
    class ROLE_STAGING,ROLE_PROD,STAGING_ROLE,PROD_ROLE iam
    class CW_LOGS logs
    class STAGING_S3,STAGING_RDS,PROD_S3,PROD_RDS account
```

## Key Resources

### EventBridge Rules

- **5-minute rule**: Cleanup tasks, health checks, metric collection
- **Hourly rule**: Log aggregation from Staging/Production CloudWatch Logs
- **Daily rule**: Database backup orchestration, cost reporting
- **Reference**:
  [EventBridge Schedule Expressions](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-create-rule-schedule.html)

### Lambda Functions (ARM64/Graviton)

- **Log Aggregator**: Pulls CloudWatch Logs from Staging/Production → Writes to Iceberg S3
- **Backup Orchestrator**: Creates RDS snapshots, copies to Iceberg S3
- **Cleanup Task**: Removes old resources, optimizes storage costs
- **Architecture**: All functions use ARM64 for better price/performance
- **Reference**:
  [Lambda with Graviton2](https://aws.amazon.com/blogs/aws/aws-lambda-functions-powered-by-aws-graviton2-processor-run-your-functions-on-arm-and-get-up-to-34-better-price-performance/)

### Iceberg S3 Bucket (Long-term Archive)

- **Purpose**: Centralized long-term storage for logs and backups
- **Lifecycle Policy**:
  - Current objects → Glacier Flexible Retrieval (90 days)
  - Glacier → Deep Archive (1 year)
  - Old versions → Glacier (30 days) → Deep Archive (90 days) → Delete (2 years)
- **Cost Optimization**: Deep Archive is ~95% cheaper than S3 Standard
- **Reference**: [S3 Glacier Storage Classes](https://aws.amazon.com/s3/storage-classes/glacier/)

### Cross-Account Access (IAM AssumeRole)

- **Pattern**: Lambda functions assume roles in Staging/Production accounts
- **Permissions**: Read-only access to S3 and RDS (list buckets, describe DB instances)
- **Trust Policy**: Staging/Production accounts trust Housekeeping account ID (374073887345)
- **Security**: No long-term credentials, only temporary STS tokens
- **Reference**:
  [Cross-Account Access with IAM Roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html)

### Route53 Hosted Zone

- **Zone**: ops.sagebrush.services
- **Purpose**: Internal operational dashboards, monitoring endpoints
- **Delegation**: DNS zone delegated from Management account

## Design Rationale

### Why Housekeeping Account?

Separating operational tooling from workload accounts provides:

- **Security isolation**: Backup/monitoring tools can't be disrupted by application failures
- **Cost visibility**: Clear separation of operational vs application costs
- **Access control**: Different teams can manage operations vs applications
- **Reference**:
  [AWS Multi-Account Strategy](https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/organizing-your-aws-environment.html)

### Why Iceberg (Long-term S3)?

Centralizing log storage with Glacier transitions:

- **Compliance**: Meet regulatory requirements for log retention (7+ years)
- **Cost optimization**: Glacier Deep Archive costs ~$0.00099/GB/month vs $0.023/GB for S3 Standard
- **Disaster recovery**: Independent backup storage if production account is compromised
- **Reference**:
  [S3 Lifecycle Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-transition-general-considerations.html)

### Why Cross-Account Read Access?

AssumeRole pattern for accessing Staging/Production:

- **Principle of least privilege**: Read-only access, can't modify production
- **Audit trail**: Every cross-account access is logged in CloudTrail
- **No shared credentials**: Temporary STS tokens expire automatically
- **Reference**:
  [STS AssumeRole Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html#bp-workloads-use-roles)

## Data Flow

1. **Scheduled Events**: EventBridge rule triggers → Lambda function invoked
2. **Cross-Account Access**: Lambda AssumeRole in Staging/Production → Temporary STS credentials
   obtained
3. **Data Collection**: Lambda reads from Staging/Production S3/RDS → Processes data
4. **Log Archival**: Lambda writes logs to Iceberg S3 → Lifecycle policy transitions to Glacier
5. **Cost Optimization**: After 90 days → Glacier Flexible Retrieval, After 1 year → Deep Archive
