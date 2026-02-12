import ArgumentParser
import AsyncHTTPClient
import Foundation
import SotoCore
import SotoIAM

@main
@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct AWS: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "AWS",
        abstract: "Piecemeal AWS infrastructure management tool",
        subcommands: [
            CreateIAM.self,
            CreateVPC.self,
            CreateVPCEndpointSecurityGroup.self,
            CreateVPCEndpoints.self,
            CreateECS.self,
            CreateALB.self,
            CreateRDS.self,
            CreateRDSPrerequisites.self,
            CreateAuroraPostgres.self,
            CreateS3.self,
            CreateTaggedS3.self,
            CreateReplicateS3.self,
            CreateLambda.self,
            CreateCodeCommit.self,
            CreateGitHubMirror.self,
            CreateCodeBuild.self,
            CreateGitHubOIDC.self,
            CreateMigrationLambda.self,
            CreateAPILambda.self,
            CreateIAMUser.self,
            DeleteIAMUser.self,
            ListIAMUsers.self,
            CreateConsoleAccessRole.self,
            CreateConsoleAccessGroup.self,
            CreateBillingRole.self,
            CreateBudget.self,
            CreateSCP.self,
            CreateRoute53.self,
            CreateSES.self,
            DeleteStack.self,
        ]
    )
}

@available(macOS 10.15, *)
struct CreateIAM: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-iam",
        abstract: "Create the SagebrushCLIRole IAM role for cross-account access"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String = "SagebrushCLIRole"

    @Option(name: .long, help: "Management account ID")
    var managementAccountId: String = "731099197338"

    func run() async throws {
        print("🏗️  Creating IAM role stack: \(stackName)")
        print("📍 Region: \(region)")
        print("🔐 Management Account: \(managementAccountId)")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: IAMStack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "ManagementAccountId": managementAccountId
                ]
            )

            print("✅ IAM role stack created successfully: \(stackName)")
            print("   Role ARN: arn:aws:iam::\(account?.rawValue ?? "ACCOUNT_ID"):role/SagebrushCLIRole")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create IAM role: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateVPC: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-vpc",
        abstract: "Create a VPC with public and private subnets"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String

    @Option(name: .long, help: "Class B of VPC (10.XXX.0.0/16)")
    var classB: String = "10"

    func run() async throws {
        print("🏗️  Creating VPC stack: \(stackName)")
        print("📍 Region: \(region)")
        print("🔢 CIDR: 10.\(classB).0.0/16")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: VPCStack(),
                region: awsRegion,
                stackName: stackName,
                parameters: ["ClassB": classB]
            )

            print("✅ VPC stack created successfully: \(stackName)")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create VPC: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateVPCEndpointSecurityGroup: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-vpc-endpoint-sg",
        abstract: "Create security group for VPC endpoints"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional)")
    var profile: String?

    @Option(name: .long, help: "AWS region")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String = "vpc-endpoint-sg"

    @Option(name: .long, help: "VPC ID")
    var vpcId: String

    @Option(name: .long, help: "VPC CIDR block (e.g., 10.20.0.0/16)")
    var vpcCidr: String

    func run() async throws {
        print("🏗️  Creating VPC endpoint security group: \(stackName)")
        print("📍 Region: \(region)")
        print("🔒 VPC: \(vpcId)")
        print("📡 CIDR: \(vpcCidr)")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: VPCEndpointSecurityGroupStack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "VpcId": vpcId,
                    "VpcCidr": vpcCidr,
                ]
            )

            print("✅ VPC endpoint security group created: \(stackName)")
            try await client.shutdown()
        } catch {
            print("❌ Failed to create security group: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateVPCEndpoints: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-vpc-endpoints",
        abstract: "Create VPC endpoints for AWS services (S3, Secrets Manager, CloudWatch, ECR) - replaces NAT Gateway"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional)")
    var profile: String?

    @Option(name: .long, help: "AWS region")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String

    @Option(name: .long, help: "VPC ID")
    var vpcId: String

    @Option(name: .long, help: "Comma-separated private subnet IDs")
    var privateSubnetIds: String

    @Option(name: .long, help: "Security group ID for interface endpoints")
    var securityGroupId: String

    func run() async throws {
        print("🏗️  Creating VPC endpoints: \(stackName)")
        print("📍 Region: \(region)")
        print("🔒 VPC: \(vpcId)")
        print("🔐 Security Group: \(securityGroupId)")
        print("📡 Private Subnets: \(privateSubnetIds)")
        print("")
        print("Creating endpoints for:")
        print("  - S3 (Gateway endpoint - FREE)")
        print("  - Secrets Manager (Interface endpoint)")
        print("  - CloudWatch Logs (Interface endpoint)")
        print("  - ECR API (Interface endpoint)")
        print("  - ECR DKR (Interface endpoint)")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: VPCEndpointsStack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "VpcId": vpcId,
                    "PrivateSubnetIds": privateSubnetIds,
                    "SecurityGroupId": securityGroupId,
                ]
            )

            print("✅ VPC endpoints created: \(stackName)")
            print("")
            print("Next steps:")
            print("1. Verify Lambda functions can access AWS services")
            print("2. Once verified, delete NAT Gateway to save $32-45/month")
            try await client.shutdown()
        } catch {
            print("❌ Failed to create VPC endpoints: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateECS: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-ecs",
        abstract: "Create an ECS cluster with Fargate support"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String

    @Option(name: .long, help: "VPC stack name to reference")
    var vpcStack: String

    @Option(name: .long, help: "Cluster name")
    var clusterName: String = "app-cluster"

    func run() async throws {
        print("🏗️  Creating ECS cluster stack: \(stackName)")
        print("📍 Region: \(region)")
        print("🔗 VPC Stack: \(vpcStack)")
        print("📦 Cluster Name: \(clusterName)")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: ECSStack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "VPCStackName": vpcStack,
                    "ClusterName": clusterName,
                ]
            )

            print("✅ ECS cluster stack created successfully: \(stackName)")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create ECS cluster: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateALB: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-alb",
        abstract: "Create an Application Load Balancer with Route53 DNS"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String

    @Option(name: .long, help: "VPC stack name to reference")
    var vpcStack: String

    @Option(name: .long, help: "ECS stack name to reference")
    var ecsStack: String

    @Option(name: .long, help: "Domain name for the application")
    var domainName: String = "nginx.local"

    func run() async throws {
        print("🏗️  Creating ALB stack: \(stackName)")
        print("📍 Region: \(region)")
        print("🔗 VPC Stack: \(vpcStack)")
        print("🔗 ECS Stack: \(ecsStack)")
        print("🌐 Domain: \(domainName)")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: ALBStack(domainName: domainName),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "VPCStackName": vpcStack,
                    "ECSStackName": ecsStack,
                    "DomainName": domainName,
                ]
            )

            print("✅ ALB stack created successfully: \(stackName)")
            print("🌐 Access your application at: http://\(domainName)")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create ALB: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateRDS: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-rds",
        abstract: "Create an Aurora Serverless v2 PostgreSQL database"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String

    @Option(name: .long, help: "VPC stack name to reference")
    var vpcStack: String

    @Option(name: .long, help: "Database name")
    var dbName: String = "app"

    @Option(name: .long, help: "Database username")
    var dbUsername: String = "postgres"

    @Option(name: .long, help: "Database password")
    var dbPassword: String

    @Option(name: .long, help: "Minimum Aurora Serverless v2 capacity (0.5 - 128 ACU)")
    var minCapacity: String = "0.5"

    @Option(name: .long, help: "Maximum Aurora Serverless v2 capacity (0.5 - 128 ACU)")
    var maxCapacity: String = "1"

    func run() async throws {
        print("🏗️  Creating Aurora Serverless v2 PostgreSQL stack: \(stackName)")
        print("📍 Region: \(region)")
        print("🔗 VPC Stack: \(vpcStack)")
        print("🗃️  Database: \(dbName)")
        print("⚡ Serverless v2 Capacity: \(minCapacity) - \(maxCapacity) ACU")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: RDSStack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "VPCStackName": vpcStack,
                    "DBName": dbName,
                    "DBUsername": dbUsername,
                    "DBPassword": dbPassword,
                    "MinCapacity": minCapacity,
                    "MaxCapacity": maxCapacity,
                ]
            )

            print("✅ Aurora Serverless v2 PostgreSQL stack created successfully: \(stackName)")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create Aurora Serverless database: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateRDSPrerequisites: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-rds-prerequisites",
        abstract: "Create RDS/Aurora prerequisites (service-linked roles) in an account"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String = "rds-prerequisites"

    func run() async throws {
        print("🔧 Creating RDS prerequisites stack: \(stackName)")
        print("📍 Region: \(region)")
        print("   This creates necessary service-linked roles for RDS/Aurora")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: RDSPrerequisitesStack(),
                region: awsRegion,
                stackName: stackName
            )

            print("✅ RDS prerequisites stack created successfully: \(stackName)")
            print("   Account is now ready for RDS/Aurora deployments")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create RDS prerequisites: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateAuroraPostgres: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-aurora-postgres",
        abstract: "Create Aurora Serverless v2 PostgreSQL with Secrets Manager and cross-account access"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String

    @Option(name: .long, help: "VPC stack name to reference")
    var vpcStack: String

    @Option(name: .long, help: "Database name")
    var dbName: String = "app"

    @Option(name: .long, help: "Database username")
    var dbUsername: String = "postgres"

    @Option(name: .long, help: "Minimum Aurora Serverless v2 capacity (0.5 - 128 ACU)")
    var minCapacity: String = "0.5"

    @Option(name: .long, help: "Maximum Aurora Serverless v2 capacity (0.5 - 128 ACU)")
    var maxCapacity: String = "1"

    @Option(name: .long, help: "Seconds until auto-pause (300-86400). Only applies when MinCapacity is 0.")
    var secondsUntilAutoPause: String = "300"

    @Option(name: .long, help: "Housekeeping account ID for cross-account secret access")
    var housekeepingAccountId: String = "374073887345"

    func run() async throws {
        print("🏗️  Creating Aurora Serverless v2 PostgreSQL stack with Secrets Manager: \(stackName)")
        print("📍 Region: \(region)")
        print("🔗 VPC Stack: \(vpcStack)")
        print("🗃️  Database: \(dbName)")
        print("👤 Username: \(dbUsername)")
        print("⚡ Serverless v2 Capacity: \(minCapacity) - \(maxCapacity) ACU")
        print("⏸️  Auto-pause: \(secondsUntilAutoPause) seconds (\(Int(secondsUntilAutoPause)! / 60) minutes)")
        print("🔐 Secrets Manager: Auto-generated credentials")
        print("🔑 Cross-account access: Housekeeping account (\(housekeepingAccountId))")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: AuroraPostgresStack(housekeepingAccountId: housekeepingAccountId),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "VPCStackName": vpcStack,
                    "DBName": dbName,
                    "DBUsername": dbUsername,
                    "MinCapacity": minCapacity,
                    "MaxCapacity": maxCapacity,
                    "SecondsUntilAutoPause": secondsUntilAutoPause,
                    "HousekeepingAccountId": housekeepingAccountId,
                ]
            )

            print("✅ Aurora Serverless v2 PostgreSQL stack created successfully: \(stackName)")
            print("   Database credentials stored in Secrets Manager")
            print("   Connection URL accessible from housekeeping account")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create Aurora Serverless database: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateS3: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-s3",
        abstract: "Create an S3 bucket"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String

    @Option(name: .long, help: "S3 bucket name (must be globally unique)")
    var bucketName: String

    @Flag(name: .long, help: "Allow public access")
    var publicAccess: Bool = false

    func run() async throws {
        print("🏗️  Creating S3 bucket stack: \(stackName)")
        print("📍 Region: \(region)")
        print("🪣 Bucket: \(bucketName)")
        print("🔓 Public Access: \(publicAccess ? "Yes" : "No")")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: S3Stack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "BucketName": bucketName,
                    "PublicAccess": publicAccess ? "true" : "false",
                ]
            )

            print("✅ S3 bucket stack created successfully: \(stackName)")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create S3 bucket: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateTaggedS3: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-tagged-s3",
        abstract: "Create S3 bucket with UID-based name and comprehensive tagging"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String

    @Option(name: .long, help: "Unique ID for bucket name (e.g., UUID)")
    var uniqueId: String

    @Option(name: .long, help: "Logical name (lambda-artifacts, user-uploads, application-logs, mailroom, email, lambda-code, billing-reports, archive)")
    var logicalName: String

    @Option(name: .long, help: "Purpose description")
    var purpose: String

    @Option(name: .long, help: "Environment (production, staging, housekeeping, neonlaw)")
    var environment: String

    @Option(name: .long, help: "Cost center (Production, Staging, Housekeeping, NeonLaw)")
    var costCenter: String

    @Flag(name: .long, help: "Enable versioning")
    var versioning: Bool = false

    func run() async throws {
        print("🏗️  Creating tagged S3 bucket stack: \(stackName)")
        print("📍 Region: \(region)")
        print("🪣 Logical Name: \(logicalName)")
        print("📝 Purpose: \(purpose)")
        print("🌍 Environment: \(environment)")
        print("💰 Cost Center: \(costCenter)")
        print("🔄 Versioning: \(versioning ? "Enabled" : "Disabled")")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: TaggedS3Stack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "UniqueId": uniqueId,
                    "LogicalName": logicalName,
                    "Purpose": purpose,
                    "Environment": environment,
                    "CostCenter": costCenter,
                    "EnableVersioning": versioning ? "true" : "false",
                ]
            )

            print("✅ Tagged S3 bucket stack created successfully: \(stackName)")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create tagged S3 bucket: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateReplicateS3: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-replicate-s3",
        abstract: "Create S3 replication setup with destination bucket in us-east-2 (no delete marker replication)"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region for destination bucket")
    var destinationRegion: String = "us-east-2"

    @Option(name: .long, help: "Source S3 bucket stack name to replicate from")
    var sourceStackName: String

    @Option(name: .long, help: "Replication stack name")
    var replicateStackName: String

    @Option(name: .long, help: "AWS region of source bucket (e.g., us-west-2)")
    var sourceRegion: String = "us-west-2"

    func run() async throws {
        print("🏗️  Creating S3 replication setup")
        print("📍 Source Stack: \(sourceStackName) (region: \(sourceRegion))")
        print("📍 Destination Stack: \(replicateStackName) (region: \(destinationRegion))")
        print("🔄 Replication: Enabled (delete markers: disabled)")

        let sourceAwsRegion = Region(rawValue: sourceRegion)
        let destinationAwsRegion = Region(rawValue: destinationRegion)

        let destinationClient: CloudFormationClient
        if let account = account {
            destinationClient = try await CloudFormationClient(account: account, region: destinationAwsRegion)
        } else {
            destinationClient = CloudFormationClient(profile: profile)
        }

        do {
            print("\n🪣 Step 1: Creating destination bucket and IAM role in \(destinationRegion)...")
            try await destinationClient.upsertStack(
                stack: ReplicateS3Stack(),
                region: destinationAwsRegion,
                stackName: replicateStackName,
                parameters: [
                    "SourceBucketStackName": sourceStackName
                ]
            )

            print("✅ Destination bucket stack created: \(replicateStackName)")

            try await destinationClient.shutdown()

            print("\n🔗 Step 2: Updating source bucket with replication configuration...")

            let sourceClient: CloudFormationClient
            if let account = account {
                sourceClient = try await CloudFormationClient(account: account, region: sourceAwsRegion)
            } else {
                sourceClient = CloudFormationClient(profile: profile)
            }

            try await sourceClient.upsertStack(
                stack: S3Stack(),
                region: sourceAwsRegion,
                stackName: sourceStackName,
                parameters: [
                    "ReplicationEnabled": "true",
                    "ReplicateStackName": replicateStackName,
                ]
            )

            print("✅ Source bucket updated with replication configuration")
            print("\n✅ S3 replication setup completed successfully!")
            print("   Source: \(sourceStackName) (\(sourceRegion))")
            print("   Destination: \(replicateStackName) (\(destinationRegion))")
            print("   Delete markers: NOT replicated")

            try await sourceClient.shutdown()
        } catch {
            print("❌ Failed to create S3 replication setup: \(error)")
            try await destinationClient.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateLambda: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-lambda",
        abstract: "Create a Lambda function with EventBridge cron trigger (every 5 minutes)"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String

    @Option(name: .long, help: "S3 stack name to reference for Lambda code storage")
    var s3Stack: String

    @Option(name: .long, help: "Lambda function name")
    var functionName: String = "FiveMinuteFunction"

    @Option(name: .long, help: "S3 key path to Lambda deployment package")
    var s3Key: String = "lambdas/five_minutes/bootstrap.zip"

    @Option(name: .long, help: "EventBridge schedule expression")
    var schedule: String = "rate(5 minutes)"

    @Option(name: .long, help: "Lambda timeout in seconds")
    var timeout: Int = 30

    @Option(name: .long, help: "Lambda memory size in MB")
    var memorySize: Int = 128

    @Flag(name: .long, help: "Enable SES permissions (send email)")
    var enableSES: Bool = false

    @Flag(name: .long, help: "Enable STS permissions (assume roles)")
    var enableSTS: Bool = false

    @Flag(name: .long, help: "Enable Cost Explorer permissions (read billing)")
    var enableCostExplorer: Bool = false

    @Option(name: .long, help: "ARN of role to assume (if enableSTS is true)")
    var assumeRoleArn: String = ""

    func run() async throws {
        print("🏗️  Creating Lambda function stack: \(stackName)")
        print("📍 Region: \(region)")
        print("🔗 S3 Stack: \(s3Stack)")
        print("⚡ Function: \(functionName)")
        print("📦 S3 Key: \(s3Key)")
        print("⏰ Schedule: \(schedule)")
        print("⏱️  Timeout: \(timeout)s")
        print("💾 Memory: \(memorySize)MB")

        var additionalPolicies: [String] = []

        if enableSES {
            print("📧 SES: Enabled")
            additionalPolicies.append(
                """
                        {
                          "PolicyName": "SESAccess",
                          "PolicyDocument": {
                            "Version": "2012-10-17",
                            "Statement": [
                              {
                                "Effect": "Allow",
                                "Action": [
                                  "ses:SendEmail",
                                  "ses:SendRawEmail"
                                ],
                                "Resource": "*"
                              }
                            ]
                          }
                        }
                """
            )
        }

        if enableSTS {
            print("🔐 STS: Enabled")
            if !assumeRoleArn.isEmpty {
                print("   Assume Role: \(assumeRoleArn)")
                additionalPolicies.append(
                    """
                            {
                              "PolicyName": "STSAssumeRole",
                              "PolicyDocument": {
                                "Version": "2012-10-17",
                                "Statement": [
                                  {
                                    "Effect": "Allow",
                                    "Action": "sts:AssumeRole",
                                    "Resource": "\(assumeRoleArn)"
                                  }
                                ]
                              }
                            }
                    """
                )
            } else {
                additionalPolicies.append(
                    """
                            {
                              "PolicyName": "STSAssumeRole",
                              "PolicyDocument": {
                                "Version": "2012-10-17",
                                "Statement": [
                                  {
                                    "Effect": "Allow",
                                    "Action": "sts:AssumeRole",
                                    "Resource": "*"
                                  }
                                ]
                              }
                            }
                    """
                )
            }
        }

        if enableCostExplorer {
            print("💰 Cost Explorer: Enabled")
            additionalPolicies.append(
                """
                        {
                          "PolicyName": "CostExplorerAccess",
                          "PolicyDocument": {
                            "Version": "2012-10-17",
                            "Statement": [
                              {
                                "Effect": "Allow",
                                "Action": [
                                  "ce:GetCostAndUsage",
                                  "ce:GetCostForecast"
                                ],
                                "Resource": "*"
                              }
                            ]
                          }
                        }
                """
            )
        }

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: LambdaStack(
                    functionName: functionName,
                    s3StackName: s3Stack,
                    s3Key: s3Key,
                    scheduleExpression: schedule,
                    timeout: timeout,
                    memorySize: memorySize,
                    additionalPolicies: additionalPolicies
                ),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "FunctionName": functionName,
                    "S3StackName": s3Stack,
                    "S3Key": s3Key,
                ]
            )

            print("✅ Lambda function stack created successfully: \(stackName)")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create Lambda function: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateCodeCommit: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-codecommit",
        abstract: "Create a CodeCommit repository"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String

    @Option(name: .long, help: "CodeCommit repository name")
    var repositoryName: String

    func run() async throws {
        print("🏗️  Creating CodeCommit repository stack: \(stackName)")
        print("📍 Region: \(region)")
        print("📦 Repository: \(repositoryName)")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: CodeCommitStack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "RepositoryName": repositoryName
                ]
            )

            print("✅ CodeCommit repository stack created successfully: \(stackName)")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create CodeCommit repository: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateGitHubMirror: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-github-mirror",
        abstract: "Create GitHub → CodeCommit mirroring infrastructure (repo + IAM user + access key)"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String

    @Option(name: .long, help: "CodeCommit repository name (e.g., sagebrush-web)")
    var repositoryName: String

    @Option(name: .long, help: "Environment (staging or production)")
    var environment: String = "staging"

    func run() async throws {
        print("🏗️  Creating GitHub mirror stack: \(stackName)")
        print("📍 Region: \(region)")
        print("📦 Repository: \(repositoryName)")
        print("🌍 Environment: \(environment)")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: GitHubMirrorStack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "RepositoryName": repositoryName,
                    "Environment": environment
                ]
            )

            print("✅ GitHub mirror stack created successfully: \(stackName)")
            print("")
            print("📋 Next steps:")
            print("   1. Retrieve access keys from CloudFormation outputs:")
            print("      aws cloudformation describe-stacks \\")
            print("        --region \(region) \\")
            print("        --stack-name \(stackName) \\")
            print("        --query 'Stacks[0].Outputs' \\")
            print("        --output table")
            print("")
            print("   2. Add secrets to GitHub repository:")
            print("      - AWS_\(environment.uppercased())_ACCESS_KEY_ID")
            print("      - AWS_\(environment.uppercased())_SECRET_ACCESS_KEY")
            print("")
            print("   3. Create GitHub Actions workflow in the repository")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create GitHub mirror stack: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateIAMUser: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-iam-user",
        abstract: "Create an IAM user with optional admin access"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Argument(help: "IAM user name")
    var userName: String

    @Flag(name: .long, help: "Attach AdministratorAccess policy")
    var admin: Bool = false

    func run() async throws {
        print("👤 Creating IAM user: \(userName)")
        if admin {
            print("🔑 Admin access: Yes")
        }

        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let awsClient: AWSClient
        if let account = account {
            let stsProvider = STSCredentialProvider(
                httpClient: httpClient,
                configuration: AWSConfiguration()
            )
            let credentials = try await stsProvider.assumeRole(
                account: account,
                region: Region(rawValue: region)
            )
            awsClient = AWSClient(
                credentialProvider: .static(
                    accessKeyId: credentials.accessKeyId,
                    secretAccessKey: credentials.secretAccessKey,
                    sessionToken: credentials.sessionToken
                ),
                httpClient: httpClient
            )
        } else if let profile = profile {
            awsClient = AWSClient(
                credentialProvider: .configFile(profile: profile),
                httpClient: httpClient
            )
        } else {
            awsClient = AWSClient(httpClient: httpClient)
        }

        let iam = IAM(client: awsClient)

        do {
            let createUserRequest = IAM.CreateUserRequest(userName: userName)
            let response = try await iam.createUser(createUserRequest)

            guard let user = response.user else {
                throw AWSClientError.stackNotFound("User creation failed")
            }

            print("✅ User created: \(user.userName)")
            print("   ARN: \(user.arn)")

            if admin {
                let attachPolicyRequest = IAM.AttachUserPolicyRequest(
                    policyArn: "arn:aws:iam::aws:policy/AdministratorAccess",
                    userName: userName
                )
                try await iam.attachUserPolicy(attachPolicyRequest)
                print("✅ AdministratorAccess policy attached")
            }

            try await awsClient.shutdown()
            try await httpClient.shutdown()
        } catch {
            print("❌ Failed to create IAM user: \(error)")
            try await awsClient.shutdown()
            try await httpClient.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct DeleteIAMUser: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete-iam-user",
        abstract: "Delete an IAM user and all associated resources"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Argument(help: "IAM user name")
    var userName: String

    func run() async throws {
        print("🗑️  Deleting IAM user: \(userName)")

        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let awsClient: AWSClient
        if let account = account {
            let stsProvider = STSCredentialProvider(
                httpClient: httpClient,
                configuration: AWSConfiguration()
            )
            let credentials = try await stsProvider.assumeRole(
                account: account,
                region: Region(rawValue: region)
            )
            awsClient = AWSClient(
                credentialProvider: .static(
                    accessKeyId: credentials.accessKeyId,
                    secretAccessKey: credentials.secretAccessKey,
                    sessionToken: credentials.sessionToken
                ),
                httpClient: httpClient
            )
        } else if let profile = profile {
            awsClient = AWSClient(
                credentialProvider: .configFile(profile: profile),
                httpClient: httpClient
            )
        } else {
            awsClient = AWSClient(httpClient: httpClient)
        }

        let iam = IAM(client: awsClient)

        do {
            let listPoliciesRequest = IAM.ListAttachedUserPoliciesRequest(userName: userName)
            let policiesResponse = try await iam.listAttachedUserPolicies(listPoliciesRequest)
            if let policies = policiesResponse.attachedPolicies {
                for policy in policies {
                    if let policyArn = policy.policyArn {
                        let detachRequest = IAM.DetachUserPolicyRequest(
                            policyArn: policyArn,
                            userName: userName
                        )
                        try await iam.detachUserPolicy(detachRequest)
                        print("   Detached policy: \(policy.policyName ?? policyArn)")
                    }
                }
            }

            let listKeysRequest = IAM.ListAccessKeysRequest(userName: userName)
            let keysResponse = try await iam.listAccessKeys(listKeysRequest)
            for key in keysResponse.accessKeyMetadata {
                if let accessKeyId = key.accessKeyId {
                    let deleteKeyRequest = IAM.DeleteAccessKeyRequest(
                        accessKeyId: accessKeyId,
                        userName: userName
                    )
                    try await iam.deleteAccessKey(deleteKeyRequest)
                    print("   Deleted access key: \(accessKeyId)")
                }
            }

            do {
                let deleteLoginRequest = IAM.DeleteLoginProfileRequest(userName: userName)
                try await iam.deleteLoginProfile(deleteLoginRequest)
                print("   Deleted login profile")
            } catch {
            }

            let deleteUserRequest = IAM.DeleteUserRequest(userName: userName)
            try await iam.deleteUser(deleteUserRequest)

            print("✅ User deleted: \(userName)")

            try await awsClient.shutdown()
            try await httpClient.shutdown()
        } catch {
            print("❌ Failed to delete IAM user: \(error)")
            try await awsClient.shutdown()
            try await httpClient.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct ListIAMUsers: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-iam-users",
        abstract: "List all IAM users in the account"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    func run() async throws {
        print("📋 Listing IAM users...")

        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let awsClient: AWSClient
        if let account = account {
            let stsProvider = STSCredentialProvider(
                httpClient: httpClient,
                configuration: AWSConfiguration()
            )
            let credentials = try await stsProvider.assumeRole(
                account: account,
                region: Region(rawValue: region)
            )
            awsClient = AWSClient(
                credentialProvider: .static(
                    accessKeyId: credentials.accessKeyId,
                    secretAccessKey: credentials.secretAccessKey,
                    sessionToken: credentials.sessionToken
                ),
                httpClient: httpClient
            )
        } else if let profile = profile {
            awsClient = AWSClient(
                credentialProvider: .configFile(profile: profile),
                httpClient: httpClient
            )
        } else {
            awsClient = AWSClient(httpClient: httpClient)
        }

        let iam = IAM(client: awsClient)

        do {
            let listUsersRequest = IAM.ListUsersRequest()
            let response = try await iam.listUsers(listUsersRequest)

            if !response.users.isEmpty {
                print("\nFound \(response.users.count) user(s):\n")
                for user in response.users {
                    print("👤 \(user.userName)")
                    print("   ARN: \(user.arn)")
                    print("   Created: \(user.createDate)")
                    if let lastUsed = user.passwordLastUsed {
                        print("   Last login: \(lastUsed)")
                    }
                    print()
                }
            } else {
                print("No IAM users found")
            }

            try await awsClient.shutdown()
            try await httpClient.shutdown()
        } catch {
            print("❌ Failed to list IAM users: \(error)")
            try await awsClient.shutdown()
            try await httpClient.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateConsoleAccessRole: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-console-access-role",
        abstract: "Create a cross-account console access role in a target account"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String = "ConsoleAccessRole"

    @Option(name: .long, help: "Management account ID")
    var managementAccountId: String = "731099197338"

    @Option(name: .long, help: "Role name")
    var roleName: String = "ConsoleAdminAccess"

    @Option(name: .long, help: "Permission level (Administrator, PowerUser, ReadOnly)")
    var permissionLevel: String = "Administrator"

    @Option(name: .long, help: "Maximum session duration in seconds (3600-43200)")
    var maxSessionDuration: Int = 3600

    func run() async throws {
        print("🏗️  Creating console access role stack: \(stackName)")
        print("📍 Region: \(region)")
        print("🔐 Management Account: \(managementAccountId)")
        print("👤 Role Name: \(roleName)")
        print("🔑 Permission Level: \(permissionLevel)")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: ConsoleAccessRoleStack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "ManagementAccountId": managementAccountId,
                    "RoleName": roleName,
                    "PermissionLevel": permissionLevel,
                    "MaxSessionDuration": String(maxSessionDuration),
                ]
            )

            print("✅ Console access role stack created successfully: \(stackName)")
            if let targetAccount = account {
                print(
                    "   Role ARN: arn:aws:iam::\(targetAccount.rawValue):role/\(roleName)"
                )
                print(
                    "   Console Link: https://signin.aws.amazon.com/switchrole?roleName=\(roleName)&account=\(targetAccount.rawValue)&displayName=\(stackName)"
                )
            }

            try await client.shutdown()
        } catch {
            print("❌ Failed to create console access role: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateConsoleAccessGroup: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-console-access-group",
        abstract:
            "Create IAM group and policies in management account for cross-account console access"
    )

    @Option(name: .long, help: "AWS profile to use")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String = "ConsoleAccessGroup"

    @Option(name: .long, help: "IAM group name")
    var groupName: String = "CrossAccountAdministrators"

    @Option(name: .long, help: "Production account ID")
    var productionAccountId: String = "978489150794"

    @Option(name: .long, help: "Staging account ID")
    var stagingAccountId: String = "889786867297"

    @Option(name: .long, help: "Housekeeping account ID")
    var housekeepingAccountId: String = "374073887345"

    @Option(name: .long, help: "NeonLaw account ID")
    var neonLawAccountId: String = "102186460229"

    @Option(name: .long, help: "Target role name in other accounts")
    var targetRoleName: String = "ConsoleAdminAccess"

    func run() async throws {
        print("🏗️  Creating console access group stack: \(stackName)")
        print("📍 Region: \(region)")
        print("👥 Group Name: \(groupName)")
        print("🎯 Target Role: \(targetRoleName)")

        let awsRegion = Region(rawValue: region)
        let client = CloudFormationClient(profile: profile)

        do {
            try await client.upsertStack(
                stack: ConsoleAccessGroupStack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "GroupName": groupName,
                    "ProductionAccountId": productionAccountId,
                    "StagingAccountId": stagingAccountId,
                    "HousekeepingAccountId": housekeepingAccountId,
                    "NeonLawAccountId": neonLawAccountId,
                    "TargetRoleName": targetRoleName,
                ]
            )

            print("✅ Console access group stack created successfully: \(stackName)")
            print("   Group Name: \(groupName)")
            print("\n📝 Next steps:")
            print("   1. Add IAM users to the '\(groupName)' group")
            print("   2. Users can switch roles in the AWS Console")
            print(
                "   3. Production: https://signin.aws.amazon.com/switchrole?roleName=\(targetRoleName)&account=\(productionAccountId)&displayName=Production"
            )
            print(
                "   4. Staging: https://signin.aws.amazon.com/switchrole?roleName=\(targetRoleName)&account=\(stagingAccountId)&displayName=Staging"
            )

            try await client.shutdown()
        } catch {
            print("❌ Failed to create console access group: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateBudget: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-budget",
        abstract: "Create an AWS Budget with cost alerts and notifications"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String = "MonthlyBudget"

    @Option(name: .long, help: "Budget name")
    var budgetName: String = "MonthlyBudget"

    @Option(name: .long, help: "Monthly budget amount in USD")
    var budgetAmount: Int = 100

    @Option(name: .long, help: "Email address for budget notifications")
    var emailAddress: String

    @Option(name: .long, help: "Alert threshold percentage (e.g., 80 for 80%)")
    var thresholdPercentage: Int = 80

    func run() async throws {
        print("🏗️  Creating budget stack: \(stackName)")
        print("📍 Region: \(region)")
        print("💰 Budget Amount: $\(budgetAmount)/month")
        print("📧 Email: \(emailAddress)")
        print("⚠️  Alert Threshold: \(thresholdPercentage)%")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: BudgetStack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "BudgetName": budgetName,
                    "BudgetAmount": String(budgetAmount),
                    "EmailAddress": emailAddress,
                    "ThresholdPercentage": String(thresholdPercentage),
                ]
            )

            print("✅ Budget stack created successfully: \(stackName)")
            print("   Budget: $\(budgetAmount)/month")
            print("   Alert at: \(thresholdPercentage)%")
            print("   Notifications: \(emailAddress)")
            print("\n📝 Next steps:")
            print("   1. Check your email to confirm SNS subscription")
            print("   2. You'll receive alerts when costs exceed \(thresholdPercentage)% of budget")
            print("   3. You'll receive forecasted alerts when costs are projected to exceed 100%")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create budget: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateSCP: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-scp",
        abstract:
            "Create a Service Control Policy (SCP) to restrict AWS regions (must be run in management account)"
    )

    @Option(name: .long, help: "AWS account to target (must be management account)")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String = "RegionRestrictionSCP"

    @Option(name: .long, help: "Policy name")
    var policyName: String = "RestrictRegions"

    @Option(name: .long, help: "Policy description")
    var policyDescription: String = "Restricts AWS API calls to us-west-2 and us-east-1 only"

    @Option(name: .long, help: "First allowed AWS region")
    var allowedRegion1: String = "us-west-2"

    @Option(name: .long, help: "Second allowed AWS region")
    var allowedRegion2: String = "us-east-1"

    @Option(name: .long, help: "Target account ID to attach this SCP to (optional)")
    var targetAccountId: String = ""

    func run() async throws {
        print("🏗️  Creating Service Control Policy stack: \(stackName)")
        print("📍 Region: \(region)")
        print("📜 Policy Name: \(policyName)")
        print("🌎 Allowed Regions: \(allowedRegion1), \(allowedRegion2)")

        if !targetAccountId.isEmpty {
            print("🎯 Target Account: \(targetAccountId)")
        }

        print(
            "\n⚠️  WARNING: This SCP must be created in the Management account (731099197338)"
        )
        print("   It will restrict all AWS API calls to only the specified regions.")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: SCPStack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "PolicyName": policyName,
                    "PolicyDescription": policyDescription,
                    "AllowedRegion1": allowedRegion1,
                    "AllowedRegion2": allowedRegion2,
                    "TargetAccountId": targetAccountId,
                ]
            )

            print("✅ Service Control Policy stack created successfully: \(stackName)")
            print("   Policy Name: \(policyName)")
            print("   Allowed Regions: \(allowedRegion1), \(allowedRegion2)")

            if !targetAccountId.isEmpty {
                print("   Attached to Account: \(targetAccountId)")
            } else {
                print("\n📝 Next steps:")
                print(
                    "   To attach this policy to an account, use the AWS Organizations console or CLI:"
                )
                print(
                    "   aws organizations attach-policy --policy-id <policy-id> --target-id <account-id>"
                )
            }

            try await client.shutdown()
        } catch {
            print("❌ Failed to create Service Control Policy: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateRoute53: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-route53",
        abstract: "Create Route53 hosted zone and DNS records for sagebrush.services"
    )

    @Option(name: .long, help: "AWS profile to use (optional)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String = "sagebrush-dns"

    @Option(name: .long, help: "Domain name")
    var domainName: String = "sagebrush.services"

    @Option(name: .long, help: "WWW A record target (ALB DNS name). Leave empty to skip.")
    var wwwTarget: String = ""

    @Option(name: .long, help: "Staging A record target (ALB DNS name). Leave empty to skip.")
    var stagingTarget: String = ""

    @Option(
        name: .long,
        help: "MX record value (e.g., '10 inbound-smtp.us-west-2.amazonaws.com'). Leave empty to skip."
    )
    var mxRecord: String = ""

    @Option(name: .long, help: "SPF TXT record value (e.g., 'v=spf1 include:amazonses.com ~all'). Leave empty to skip.")
    var spfRecord: String = ""

    @Option(name: .long, help: "DMARC TXT record value (e.g., 'v=DMARC1; p=quarantine'). Leave empty to skip.")
    var dmarcRecord: String = ""

    @Option(name: .long, help: "SES DKIM token 1 (name part). Leave empty to skip.")
    var dkimToken1: String = ""

    @Option(name: .long, help: "SES DKIM value 1 (target part). Leave empty to skip.")
    var dkimValue1: String = ""

    @Option(name: .long, help: "SES DKIM token 2 (name part). Leave empty to skip.")
    var dkimToken2: String = ""

    @Option(name: .long, help: "SES DKIM value 2 (target part). Leave empty to skip.")
    var dkimValue2: String = ""

    @Option(name: .long, help: "SES DKIM token 3 (name part). Leave empty to skip.")
    var dkimToken3: String = ""

    @Option(name: .long, help: "SES DKIM value 3 (target part). Leave empty to skip.")
    var dkimValue3: String = ""

    func run() async throws {
        print("🏗️  Creating Route53 hosted zone stack: \(stackName)")
        print("📍 Region: \(region)")
        print("🌐 Domain: \(domainName)")

        if !wwwTarget.isEmpty {
            print("📍 WWW Record: www.\(domainName) -> \(wwwTarget)")
        }
        if !stagingTarget.isEmpty {
            print("📍 Staging Record: staging.\(domainName) -> \(stagingTarget)")
        }
        if !mxRecord.isEmpty {
            print("📧 MX Record: \(mxRecord)")
        }

        let awsRegion = Region(rawValue: region)
        let client = CloudFormationClient(profile: profile)

        do {
            try await client.upsertStack(
                stack: Route53Stack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "DomainName": domainName,
                    "WWWRecordTarget": wwwTarget,
                    "StagingRecordTarget": stagingTarget,
                    "MXRecordValue": mxRecord,
                    "SPFRecord": spfRecord,
                    "DMARCRecord": dmarcRecord,
                    "DKIMToken1": dkimToken1,
                    "DKIMValue1": dkimValue1,
                    "DKIMToken2": dkimToken2,
                    "DKIMValue2": dkimValue2,
                    "DKIMToken3": dkimToken3,
                    "DKIMValue3": dkimValue3,
                ]
            )

            print("✅ Route53 hosted zone stack created successfully: \(stackName)")
            print("\n📝 Next steps:")
            print("   1. Get nameservers from CloudFormation outputs")
            print("   2. Update domain registrar with these nameservers")
            print("   3. Wait 24-48 hours for DNS propagation")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create Route53 stack: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateSES: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-ses",
        abstract: "Create SES domain and email identities in housekeeping account"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String = "sagebrush-ses"

    @Option(name: .long, help: "Domain name")
    var domainName: String = "sagebrush.services"

    @Option(name: .long, help: "Email address to verify")
    var emailAddress: String = "support@sagebrush.services"

    func run() async throws {
        print("🏗️  Creating SES domain identity stack: \(stackName)")
        print("📍 Region: \(region)")
        print("🌐 Domain: \(domainName)")
        print("📧 Email: \(emailAddress)")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: SESStack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "DomainName": domainName,
                    "EmailAddress": emailAddress,
                ]
            )

            print("✅ SES domain identity stack created successfully: \(stackName)")
            print("\n📝 Next steps:")
            print("   1. Get DKIM tokens from CloudFormation outputs (DKIMToken1/2/3 and DKIMValue1/2/3)")
            print("   2. Update Route53 stack with DKIM records:")
            print("      swift run AWS create-route53 \\")
            print("        --dkim-token1 <token1> --dkim-value1 <value1> \\")
            print("        --dkim-token2 <token2> --dkim-value2 <value2> \\")
            print("        --dkim-token3 <token3> --dkim-value3 <value3>")
            print("   3. Wait for DNS propagation")
            print("   4. AWS will automatically verify domain and email")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create SES stack: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateCodeBuild: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-codebuild",
        abstract: "Create a CodeBuild project for building Swift Lambda on ARM64"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String

    @Option(name: .long, help: "CodeBuild project name")
    var projectName: String

    @Option(name: .long, help: "CodeCommit repository name")
    var codecommitRepo: String

    @Option(name: .long, help: "S3 bucket name for Lambda artifacts")
    var s3Bucket: String

    @Option(name: .long, help: "Lambda function name to update")
    var lambdaFunction: String

    func run() async throws {
        print("🏗️  Creating CodeBuild project stack: \(stackName)")
        print("📍 Region: \(region)")
        print("📦 Project Name: \(projectName)")
        print("🔗 CodeCommit Repo: \(codecommitRepo)")
        print("🪣 S3 Bucket: \(s3Bucket)")
        print("λ  Lambda Function: \(lambdaFunction)")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: CodeBuildStack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "ProjectName": projectName,
                    "CodeCommitRepositoryName": codecommitRepo,
                    "S3BucketName": s3Bucket,
                    "LambdaFunctionName": lambdaFunction,
                ]
            )

            print("✅ CodeBuild project stack created successfully: \(stackName)")
            print("   Project: \(projectName)")
            print("   Source: CodeCommit repository '\(codecommitRepo)'")
            print("   Artifacts: S3 bucket '\(s3Bucket)'")
            print("   Target Lambda: \(lambdaFunction)")
            print("\n📝 Next steps:")
            print("   1. Add buildspec.yml to the root of your CodeCommit repository")
            print("   2. Push code to CodeCommit to trigger a build")
            print("   3. CodeBuild will compile Swift on Amazon Linux 2023 ARM64")
            print("   4. Build artifacts will be uploaded to S3")
            print("   5. Lambda function will be updated automatically")
            print("   6. Lambda will be invoked to run migrations")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create CodeBuild project: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateGitHubOIDC: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-github-oidc",
        abstract: "Create GitHub OIDC provider and IAM role for GitHub Actions"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String = "GitHubOIDC"

    @Option(name: .long, help: "GitHub organization name")
    var githubOrg: String = "NeonLawFoundation"

    @Option(name: .long, help: "GitHub repository name")
    var githubRepo: String = "Standards"

    @Option(name: .long, help: "CodeCommit repository ARN to grant access to")
    var codecommitArn: String

    func run() async throws {
        print("🏗️  Creating GitHub OIDC provider stack: \(stackName)")
        print("📍 Region: \(region)")
        print("🐙 GitHub: \(githubOrg)/\(githubRepo)")
        print("🔗 CodeCommit ARN: \(codecommitArn)")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: GitHubOIDCStack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "GitHubOrganization": githubOrg,
                    "GitHubRepository": githubRepo,
                    "CodeCommitRepositoryArn": codecommitArn,
                ]
            )

            print("✅ GitHub OIDC provider stack created successfully: \(stackName)")
            print("   OIDC Provider: token.actions.githubusercontent.com")
            print("   IAM Role: GitHubActionsCodeCommitRole")
            print("   Allowed Repository: \(githubOrg)/\(githubRepo)")
            print("   Permissions: codecommit:GitPull, codecommit:GitPush")
            print("\n📝 Next steps:")
            print("   1. Add the following to your GitHub Actions workflow:")
            print("      permissions:")
            print("        id-token: write")
            print("        contents: read")
            print("   2. Configure AWS credentials in your workflow:")
            print("      - uses: aws-actions/configure-aws-credentials@v4")
            print("        with:")
            if let account = account {
                print("          role-to-assume: arn:aws:iam::\(account.rawValue):role/GitHubActionsCodeCommitRole")
            } else {
                print("          role-to-assume: arn:aws:iam::<ACCOUNT_ID>:role/GitHubActionsCodeCommitRole")
            }
            print("          aws-region: \(region)")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create GitHub OIDC provider: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateMigrationLambda: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-migration-lambda",
        abstract: "Create Migration Lambda function with VPC and Aurora access"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String

    @Option(name: .long, help: "Lambda function name")
    var functionName: String = "MigrationRunner"

    @Option(name: .long, help: "VPC stack name to reference")
    var vpcStack: String = "oregon-vpc"

    @Option(name: .long, help: "Aurora PostgreSQL stack name to reference")
    var auroraStack: String

    @Option(name: .long, help: "S3 bucket name for Lambda code")
    var s3Bucket: String

    @Option(name: .long, help: "S3 key path to Lambda deployment package")
    var s3Key: String = "lambda/migration-runner/bootstrap.zip"

    func run() async throws {
        print("🏗️  Creating Migration Lambda stack: \(stackName)")
        print("📍 Region: \(region)")
        print("λ  Function: \(functionName)")
        print("🔗 VPC Stack: \(vpcStack)")
        print("🗃️  Aurora Stack: \(auroraStack)")
        print("🪣 S3 Bucket: \(s3Bucket)")
        print("🔑 S3 Key: \(s3Key)")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: MigrationLambdaStack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "FunctionName": functionName,
                    "VPCStackName": vpcStack,
                    "AuroraStackName": auroraStack,
                    "S3BucketName": s3Bucket,
                    "S3Key": s3Key,
                ]
            )

            print("✅ Migration Lambda stack created successfully: \(stackName)")
            print("   Function: \(functionName)")
            print("   Runtime: provided.al2023 (Swift)")
            print("   Architecture: arm64")
            print("   VPC: Private subnets from \(vpcStack)")
            print("   Database: Connected to \(auroraStack)")
            print("   Timeout: 300 seconds")
            print("   Memory: 512 MB")
            print("\n📝 Next steps:")
            print("   1. Build your Swift Lambda code with CodeBuild")
            print("   2. CodeBuild will upload the zip to S3 and update this function")
            print("   3. Invoke the Lambda to run migrations and seeds:")
            print("      aws lambda invoke --function-name \(functionName) response.json")
            print("   4. Check CloudWatch Logs for migration results:")
            print("      aws logs tail /aws/lambda/\(functionName) --follow")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create Migration Lambda: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateAPILambda: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-api-lambda",
        abstract: "Create API Lambda with API Gateway integration"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String = "staging-api"

    @Option(name: .long, help: "VPC stack name to reference")
    var vpcStack: String = "oregon-vpc"

    @Option(name: .long, help: "Aurora PostgreSQL stack name to reference")
    var auroraStack: String = "staging-aurora-postgres"

    @Option(name: .long, help: "S3 stack name to reference")
    var s3Stack: String = "staging-s3"

    @Option(name: .long, help: "S3 bucket containing Lambda deployment package")
    var codeBucket: String

    @Option(name: .long, help: "S3 key for Lambda deployment package")
    var codeKey: String = "api/bootstrap.zip"

    func run() async throws {
        print("🏗️  Creating API Lambda stack: \(stackName)")
        print("📍 Region: \(region)")
        print("🔗 VPC Stack: \(vpcStack)")
        print("🗃️  Aurora Stack: \(auroraStack)")
        print("🪣 S3 Stack: \(s3Stack)")
        print("📦 Lambda Code: s3://\(codeBucket)/\(codeKey)")

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.upsertStack(
                stack: APILambdaStack(
                    vpcStackName: vpcStack,
                    auroraStackName: auroraStack,
                    s3StackName: s3Stack
                ),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "VPCStackName": vpcStack,
                    "AuroraStackName": auroraStack,
                    "S3StackName": s3Stack,
                    "FunctionCodeBucket": codeBucket,
                    "FunctionCodeKey": codeKey,
                ]
            )

            print("✅ API Lambda stack created successfully: \(stackName)")
            print("   Lambda Function: \(stackName)-api")
            print("   Runtime: provided.al2023 (Swift)")
            print("   Architecture: arm64")
            print("   VPC: Private subnets from \(vpcStack)")
            print("   Database: Connected to \(auroraStack)")
            print("   Storage: Connected to \(s3Stack)")
            print("\n📝 Next steps:")
            print("   1. Get the API Gateway endpoint from CloudFormation outputs")
            print("   2. Test the /health endpoint:")
            print("      curl https://<api-id>.execute-api.\(region).amazonaws.com/health")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create API Lambda: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct DeleteStack: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete-stack",
        abstract: "Delete a CloudFormation stack"
    )

    @Option(name: .long, help: "AWS account to target")
    var account: Account?

    @Option(name: .long, help: "AWS profile to use (optional, ignored if --account is specified)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Argument(help: "Stack name to delete")
    var stackName: String

    @Flag(name: .long, help: "Skip confirmation prompt")
    var force: Bool = false

    func run() async throws {
        print("🗑️  Deleting CloudFormation stack: \(stackName)")
        print("📍 Region: \(region)")
        if let account = account {
            print("🔐 Account: \(account.displayName) (\(account.rawValue))")
        }

        if !force {
            print("\n⚠️  WARNING: This will delete the stack and all its resources!")
            print("   Stack name: \(stackName)")
            print("   Region: \(region)")
            print("\nType 'delete' to confirm: ", terminator: "")
            guard let input = readLine(), input.lowercased() == "delete" else {
                print("❌ Deletion cancelled")
                throw ExitCode.failure
            }
        }

        let awsRegion = Region(rawValue: region)
        let client: CloudFormationClient
        if let account = account {
            client = try await CloudFormationClient(account: account, region: awsRegion)
        } else {
            client = CloudFormationClient(profile: profile)
        }

        do {
            try await client.deleteStack(stackName: stackName, region: awsRegion)
            print("✅ Stack deleted successfully: \(stackName)")
            try await client.shutdown()
        } catch {
            print("❌ Failed to delete stack: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}

@available(macOS 10.15, *)
struct CreateBillingRole: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create-billing-role",
        abstract: "Create the BillingReadRole IAM role in Management account for Cost Explorer access"
    )

    @Option(name: .long, help: "AWS profile to use (optional)")
    var profile: String?

    @Option(name: .long, help: "AWS region (e.g., us-west-2)")
    var region: String = "us-west-2"

    @Option(name: .long, help: "Stack name")
    var stackName: String = "BillingReadRole"

    @Option(name: .long, help: "Housekeeping account ID")
    var housekeepingAccountId: String = "374073887345"

    @Option(name: .long, help: "Role name")
    var roleName: String = "BillingReadRole"

    func run() async throws {
        print("🏗️  Creating billing read role stack: \(stackName)")
        print("📍 Region: \(region)")
        print("🏠 Housekeeping Account: \(housekeepingAccountId)")
        print("👤 Role Name: \(roleName)")
        print("")
        print("⚠️  This role should be deployed to the Management account (731099197338)")
        print("   The Housekeeping account will assume this role to read billing data.")

        let awsRegion = Region(rawValue: region)
        let client = CloudFormationClient(profile: profile)

        do {
            try await client.upsertStack(
                stack: BillingReadRoleStack(),
                region: awsRegion,
                stackName: stackName,
                parameters: [
                    "HousekeepingAccountId": housekeepingAccountId,
                    "RoleName": roleName,
                ]
            )

            print("✅ Billing read role stack created successfully: \(stackName)")
            print("   Role ARN: arn:aws:iam::731099197338:role/\(roleName)")
            print("")
            print("Next steps:")
            print("1. Verify the Lambda execution role in Housekeeping account has permission to assume this role")
            print("2. Deploy the DailyBilling Lambda function to the Housekeeping account")

            try await client.shutdown()
        } catch {
            print("❌ Failed to create billing read role: \(error)")
            try await client.shutdown()
            throw ExitCode.failure
        }
    }
}
