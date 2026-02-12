# Sagebrush AWS Infrastructure

Swift-based infrastructure as code for AWS using CloudFormation.

## About Sagebrush Services

Sagebrush Services provides a **physical home and business address** for various companies in our portfolio. We operate
as a virtual mailbox service, handling physical mail processing, business registration addresses, and compliance
requirements for multiple legal entities.

## Architecture

- **Stack Protocol** - CloudFormation templates as Swift structs with `templateBody` JSON
- **Soto SDK** - AWS SDK for Swift (CloudFormation, IAM, RDS, Lambda, etc.)
- **CLI Tool** - Swift executable with ArgumentParser for stack management
- **Cross-Account** - AssumeRole via OrganizationAccountAccessRole from management account

## Stack Pattern

Each stack:

1. Conforms to `Stack` protocol
2. Contains CloudFormation JSON in `templateBody`
3. **Exports outputs** using `Export: { Name: { "Fn::Sub": "${AWS::StackName}-OutputName" } }`
4. **Imports from other stacks** using `Fn::ImportValue: "StackName-OutputName"`

This pattern ensures consistent naming and cross-stack references.

## Structure

```txt
Sources/
├── main.swift              # CLI commands (create-vpc, create-rds, etc.)
├── Stack.swift             # Stack protocol definition
├── AWSClient.swift         # CloudFormation client wrapper
├── Account.swift           # AWS account enumeration
└── Stacks/
    ├── VPCStack.swift      # Exports: VPC, SubnetsPublic, SubnetsPrivate
    ├── RDSStack.swift      # Imports: VPC, subnets from VPCStack
    ├── LambdaStack.swift   # Imports: VPC, subnets from VPCStack
    └── ...                 # 25+ infrastructure stacks
```

## Workflow

```bash
# Build CLI
swift build -c release

# Create foundational stack (exports VPC, subnets)
.build/release/AWS create-vpc --account staging --stack-name vpc

# Create dependent stack (imports from vpc stack)
.build/release/AWS create-rds --account staging --stack-name db

# Delete stack
.build/release/AWS delete-stack --account staging --stack-name db
```

## Key Principles

- **Swift only** - No Terraform, CDK, or other IaC tools
- **CloudFormation native** - Direct AWS CloudFormation API calls via Soto
- **Export/Import chains** - Stacks reference each other through CloudFormation exports
- **Immutable templates** - Stack definitions are code, not YAML files
- **Type-safe** - Swift compiler validates stack structure

## Documentation Requirements

**CRITICAL - MANDATORY AFTER EVERY INFRASTRUCTURE CHANGE**:

After creating, updating, or deleting **ANY** AWS resource, you **MUST**:

1. **Update `DEPLOYED_RESOURCES.md`** immediately with the change
   - This is **NON-NEGOTIABLE** - never skip this step
   - Update the "Last Updated" date at the top of the file
   - Add details about new resources (ID, ARN, configuration, cost estimate)
   - Remove deleted resources completely
   - Update related sections if dependencies changed

2. **Regenerate architecture diagrams** if the change affects infrastructure

   ```bash
   cd diagrams
   uv run generate.py
   ```

   - The diagrams are automatically generated from `DEPLOYED_RESOURCES.md`
   - Review the generated PNG files to verify they reflect the changes

**Why This Matters**:

- `DEPLOYED_RESOURCES.md` is the **single source of truth** for all deployed infrastructure across all 5 AWS accounts
- Architecture diagrams are generated from this file - keeping it accurate
  ensures diagrams stay synchronized
- Other team members and automation rely on this documentation being current
- Incomplete documentation leads to orphaned resources and unexpected costs

**If you deploy infrastructure without updating documentation, the deployment is incomplete.**
