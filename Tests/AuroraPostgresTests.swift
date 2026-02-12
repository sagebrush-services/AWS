import AsyncHTTPClient
import Foundation
import SotoCloudFormation
import SotoCore
import SotoRDS
import SotoSecretsManager
import Testing

@testable import AWS

@Suite("Aurora Postgres with Secrets Manager Tests")
struct AuroraPostgresTests {
    @Test("AuroraPostgresStack template is valid JSON")
    func testTemplateIsValidJSON() {
        let stack = AuroraPostgresStack()
        let data = Data(stack.templateBody.utf8)

        // Verify it's valid JSON
        let json = try? JSONSerialization.jsonObject(with: data)
        #expect(json != nil, "Template should be valid JSON")

        // Verify it's a dictionary (object)
        #expect(json is [String: Any], "Template should be a JSON object")
    }

    @Test("AuroraPostgresStack has valid CloudFormation template")
    func testTemplateStructure() throws {
        let stack = AuroraPostgresStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Issue.record("Template is not a valid JSON object")
            return
        }

        // Verify required top-level keys
        #expect(template["AWSTemplateFormatVersion"] != nil, "Should have AWSTemplateFormatVersion")
        #expect(template["Description"] != nil, "Should have Description")
        #expect(template["Parameters"] != nil, "Should have Parameters")
        #expect(template["Resources"] != nil, "Should have Resources")
        #expect(template["Outputs"] != nil, "Should have Outputs")

        // Verify resources
        guard let resources = template["Resources"] as? [String: Any] else {
            Issue.record("Resources should be a JSON object")
            return
        }

        let expectedResources = [
            "DBSecret", "DBSecretResourcePolicy", "DBSubnetGroup", "DBSecurityGroup",
            "DBCluster", "DBInstance", "DBSecretAttachment",
        ]

        for resourceName in expectedResources {
            #expect(resources[resourceName] != nil, "Should have resource: \(resourceName)")
        }
    }

    @Test("AuroraPostgresStack exports required outputs")
    func testOutputs() throws {
        let stack = AuroraPostgresStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let outputs = template["Outputs"] as? [String: Any]
        else {
            Issue.record("Template should have Outputs section")
            return
        }

        let expectedOutputs = [
            "ClusterEndpoint", "ClusterReadEndpoint", "DatabasePort", "DatabaseName",
            "SecretArn", "SecurityGroupId",
        ]

        for outputName in expectedOutputs {
            #expect(outputs[outputName] != nil, "Should have output: \(outputName)")
        }
    }

    @Test(
        "Create and verify Aurora Postgres stack with Secrets Manager in LocalStack",
        .enabled(if: false)
    )
    func testCreateAuroraPostgresStack() async throws {
        let configuration = AWSConfiguration()
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)

        let stackName = "test-aurora-postgres"
        let vpcStackName = "test-vpc"
        let housekeepingAccountId = "374073887345"

        let awsClient = SotoCore.AWSClient(httpClient: httpClient)

        // Step 1: Create VPC stack first
        print("📦 Creating VPC stack for testing...")
        let cloudFormation = CloudFormation(
            client: awsClient,
            region: .useast1,
            endpoint: configuration.endpoint
        )

        let vpcStack = VPCStack()
        let createVPCRequest = CloudFormation.CreateStackInput(
            capabilities: [.capabilityIam, .capabilityNamedIam],
            parameters: [
                CloudFormation.Parameter(parameterKey: "ClassB", parameterValue: "10")
            ],
            stackName: vpcStackName,
            templateBody: vpcStack.templateBody
        )

        _ = try await cloudFormation.createStack(createVPCRequest)
        print("✅ VPC stack creation initiated")

        // Wait for VPC stack to complete
        try await waitForStackCompletion(
            cloudFormation: cloudFormation,
            stackName: vpcStackName
        )

        // Step 2: Create Aurora Postgres stack
        print("\n📦 Creating Aurora Postgres stack...")
        let auroraStack = AuroraPostgresStack(housekeepingAccountId: housekeepingAccountId)
        let createAuroraRequest = CloudFormation.CreateStackInput(
            capabilities: [.capabilityIam, .capabilityNamedIam],
            parameters: [
                CloudFormation.Parameter(parameterKey: "VPCStackName", parameterValue: vpcStackName),
                CloudFormation.Parameter(parameterKey: "DBName", parameterValue: "testdb"),
                CloudFormation.Parameter(parameterKey: "DBUsername", parameterValue: "testuser"),
                CloudFormation.Parameter(parameterKey: "MinCapacity", parameterValue: "0.5"),
                CloudFormation.Parameter(parameterKey: "MaxCapacity", parameterValue: "1"),
                CloudFormation.Parameter(
                    parameterKey: "HousekeepingAccountId",
                    parameterValue: housekeepingAccountId
                ),
            ],
            stackName: stackName,
            templateBody: auroraStack.templateBody
        )

        _ = try await cloudFormation.createStack(createAuroraRequest)
        print("✅ Aurora Postgres stack creation initiated")

        // Wait for Aurora stack to complete
        try await waitForStackCompletion(
            cloudFormation: cloudFormation,
            stackName: stackName
        )

        // Step 3: Verify CloudFormation stack outputs
        print("\n🔍 Verifying CloudFormation stack outputs...")
        let describeRequest = CloudFormation.DescribeStacksInput(stackName: stackName)
        let stackResponse = try await cloudFormation.describeStacks(describeRequest)

        guard let stack = stackResponse.stacks?.first else {
            Issue.record("CloudFormation stack not found")
            return
        }

        #expect(stack.stackName == stackName, "Stack name should match")
        #expect(stack.stackStatus == .createComplete, "Stack should be in CREATE_COMPLETE state")

        guard let outputs = stack.outputs else {
            Issue.record("Stack has no outputs")
            return
        }

        // Verify outputs
        let expectedOutputs = [
            "ClusterEndpoint", "ClusterReadEndpoint", "DatabasePort", "DatabaseName",
            "SecretArn", "SecurityGroupId",
        ]

        for outputKey in expectedOutputs {
            let output = outputs.first { $0.outputKey == outputKey }
            #expect(output != nil, "Output '\(outputKey)' should exist")
            #expect(output?.outputValue?.isEmpty == false, "Output '\(outputKey)' should have a value")
        }

        print("✅ All expected outputs present")

        // Step 4: Verify Aurora cluster
        print("\n🔍 Verifying Aurora cluster...")
        let rds = RDS(
            client: awsClient,
            region: .useast1,
            endpoint: configuration.endpoint
        )

        let clusterIdentifier = "\(stackName)-cluster"
        let clustersRequest = RDS.DescribeDBClustersMessage(
            dbClusterIdentifier: clusterIdentifier
        )
        let clustersResponse = try await rds.describeDBClusters(clustersRequest)

        guard let cluster = clustersResponse.dbClusters?.first else {
            Issue.record("Aurora cluster not found in RDS")
            return
        }

        #expect(cluster.dbClusterIdentifier == clusterIdentifier, "Cluster identifier should match")
        #expect(cluster.engine == "aurora-postgresql", "Engine should be aurora-postgresql")
        #expect(cluster.engineMode == "provisioned", "Engine mode should be provisioned")
        #expect(cluster.databaseName == "testdb", "Database name should match")

        print("✅ Aurora cluster verified")

        // Step 5: Verify Secrets Manager secrets
        print("\n🔍 Verifying Secrets Manager secrets...")
        let secretsManager = SecretsManager(
            client: awsClient,
            region: .useast1,
            endpoint: configuration.endpoint
        )

        // Get secret ARN from outputs
        guard
            let secretArnOutput = outputs.first(where: { $0.outputKey == "SecretArn" }),
            let secretArn = secretArnOutput.outputValue
        else {
            Issue.record("SecretArn output not found")
            return
        }

        // Verify database credentials secret
        let describeSecretRequest = SecretsManager.DescribeSecretRequest(secretId: secretArn)
        let secretDescription = try await secretsManager.describeSecret(describeSecretRequest)

        #expect(secretDescription.arn == secretArn, "Secret ARN should match")
        #expect(secretDescription.name != nil, "Secret should have a name")

        // Get secret value to verify it contains connection info (added by SecretTargetAttachment)
        let getSecretRequest = SecretsManager.GetSecretValueRequest(secretId: secretArn)
        let secretValue = try await secretsManager.getSecretValue(getSecretRequest)

        #expect(secretValue.secretString != nil, "Secret should have a string value")

        if let secretString = secretValue.secretString {
            #expect(secretString.contains("host"), "Secret should contain host after attachment")
            #expect(secretString.contains("port"), "Secret should contain port after attachment")
            print("✅ Database secret verified with connection info")
        }

        // Step 6: Clean up
        print("\n🧹 Cleaning up test resources...")
        let deleteAuroraRequest = CloudFormation.DeleteStackInput(stackName: stackName)
        _ = try await cloudFormation.deleteStack(deleteAuroraRequest)

        let deleteVPCRequest = CloudFormation.DeleteStackInput(stackName: vpcStackName)
        _ = try await cloudFormation.deleteStack(deleteVPCRequest)

        print("✅ Test completed successfully!")

        try await awsClient.shutdown()
        try await httpClient.shutdown()
    }

    /// Helper function to wait for stack completion
    private func waitForStackCompletion(
        cloudFormation: CloudFormation,
        stackName: String,
        maxAttempts: Int = 60
    ) async throws {
        var attempts = 0

        while attempts < maxAttempts {
            let describeRequest = CloudFormation.DescribeStacksInput(stackName: stackName)
            let response = try await cloudFormation.describeStacks(describeRequest)

            guard let stack = response.stacks?.first,
                let status = stack.stackStatus
            else {
                throw TestError.stackNotFound(stackName)
            }

            switch status {
            case .createComplete, .updateComplete:
                print("✅ Stack operation completed: \(stackName)")
                return
            case .createFailed, .updateFailed, .rollbackComplete, .rollbackFailed,
                .updateRollbackComplete, .updateRollbackFailed:
                throw TestError.stackOperationFailed(stackName, status.rawValue)
            default:
                print("⏳ Stack status: \(status.rawValue)")
                try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
                attempts += 1
            }
        }

        throw TestError.timeout(stackName)
    }

    enum TestError: Error {
        case stackNotFound(String)
        case stackOperationFailed(String, String)
        case timeout(String)
    }
}
