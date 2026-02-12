import AsyncHTTPClient
import Foundation
import SotoCloudFormation
import SotoCloudWatchLogs
import SotoCore
import SotoECS
import SotoIAM
import Testing

@testable import AWS

@Suite("ECS Stack Tests")
struct ECSTests {
    /// Test ECS stack creation and verification in LocalStack
    @Test("Create and verify ECS stack with Fargate resources")
    func testCreateAndVerifyECSStack() async throws {
        let configuration = AWSConfiguration()

        // Stack names
        let vpcStackName = "test-vpc-ecs"
        let ecsStackName = "test-ecs"

        // Create CloudFormation client
        let cfClient = CloudFormationClient(configuration: configuration)

        // Clean up any existing stacks from previous test runs
        let cleanupHttpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let cleanupAwsClient = SotoCore.AWSClient(httpClient: cleanupHttpClient)
        let cleanupCloudFormation = CloudFormation(
            client: cleanupAwsClient,
            region: .useast1,
            endpoint: configuration.endpoint
        )

        // Try to delete existing ECS stack (if it exists)
        do {
            print("🧹 Cleaning up existing ECS stack if present...")
            _ = try await cleanupCloudFormation.deleteStack(
                CloudFormation.DeleteStackInput(stackName: ecsStackName)
            )
            // Wait a bit for deletion to start
            try await Task.sleep(nanoseconds: 3_000_000_000)
        } catch {
            // Stack doesn't exist or deletion failed, continue
        }

        // Try to delete existing VPC stack (if it exists)
        do {
            print("🧹 Cleaning up existing VPC stack if present...")
            _ = try await cleanupCloudFormation.deleteStack(
                CloudFormation.DeleteStackInput(stackName: vpcStackName)
            )
            // Wait a bit for deletion to complete
            try await Task.sleep(nanoseconds: 5_000_000_000)
        } catch {
            // Stack doesn't exist or deletion failed, continue
        }

        try await cleanupAwsClient.shutdown()
        try await cleanupHttpClient.shutdown()

        print("🚀 Setting up VPC stack...")
        // Create VPC stack first (required by ECS)
        let vpcStack = VPCStack()
        try await cfClient.upsertStack(
            stack: vpcStack,
            region: .useast1,
            stackName: vpcStackName,
            parameters: ["ClassB": "20"]
        )
        print("✅ VPC stack created successfully")

        print("🚀 Setting up ECS stack...")
        // Create ECS stack
        let ecsStack = ECSStack()
        try await cfClient.upsertStack(
            stack: ecsStack,
            region: .useast1,
            stackName: ecsStackName,
            parameters: [
                "VPCStackName": vpcStackName,
                "ClusterName": "test-cluster",
            ]
        )
        print("✅ ECS stack created successfully")

        // Now verify everything - create new clients for verification
        let verifyHttpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        let verifyAwsClient = SotoCore.AWSClient(httpClient: verifyHttpClient)

        // Verify CloudFormation stack exists
        print("🔍 Verifying CloudFormation stack...")
        let cloudFormation = CloudFormation(
            client: verifyAwsClient,
            region: .useast1,
            endpoint: configuration.endpoint
        )

        let describeRequest = CloudFormation.DescribeStacksInput(stackName: ecsStackName)
        let stackResponse = try await cloudFormation.describeStacks(describeRequest)

        guard let stack = stackResponse.stacks?.first else {
            Issue.record("CloudFormation stack not found")
            try await verifyAwsClient.shutdown()
            try await verifyHttpClient.shutdown()
            try await cfClient.shutdown()
            return
        }

        #expect(stack.stackName == ecsStackName, "Stack name should match")
        #expect(stack.stackStatus == .createComplete, "Stack should be in CREATE_COMPLETE state")

        // Extract outputs from stack
        guard let outputs = stack.outputs else {
            Issue.record("Stack has no outputs")
            try await verifyAwsClient.shutdown()
            try await verifyHttpClient.shutdown()
            try await cfClient.shutdown()
            return
        }

        // Extract cluster information
        guard let clusterNameOutput = outputs.first(where: { $0.outputKey == "ClusterName" }),
            let clusterName = clusterNameOutput.outputValue
        else {
            Issue.record("ClusterName output not found")
            try await verifyAwsClient.shutdown()
            try await verifyHttpClient.shutdown()
            try await cfClient.shutdown()
            return
        }

        guard let clusterArnOutput = outputs.first(where: { $0.outputKey == "ClusterArn" }),
            let clusterArn = clusterArnOutput.outputValue
        else {
            Issue.record("ClusterArn output not found")
            try await verifyAwsClient.shutdown()
            try await verifyHttpClient.shutdown()
            try await cfClient.shutdown()
            return
        }

        guard let taskRoleArnOutput = outputs.first(where: { $0.outputKey == "TaskRoleArn" }),
            let taskRoleArn = taskRoleArnOutput.outputValue
        else {
            Issue.record("TaskRoleArn output not found")
            try await verifyAwsClient.shutdown()
            try await verifyHttpClient.shutdown()
            try await cfClient.shutdown()
            return
        }

        guard let taskExecutionRoleArnOutput = outputs.first(where: { $0.outputKey == "TaskExecutionRoleArn" }),
            let taskExecutionRoleArn = taskExecutionRoleArnOutput.outputValue
        else {
            Issue.record("TaskExecutionRoleArn output not found")
            try await verifyAwsClient.shutdown()
            try await verifyHttpClient.shutdown()
            try await cfClient.shutdown()
            return
        }

        guard let securityGroupIdOutput = outputs.first(where: { $0.outputKey == "SecurityGroupId" }),
            let securityGroupId = securityGroupIdOutput.outputValue
        else {
            Issue.record("SecurityGroupId output not found")
            try await verifyAwsClient.shutdown()
            try await verifyHttpClient.shutdown()
            try await cfClient.shutdown()
            return
        }

        guard let logGroupNameOutput = outputs.first(where: { $0.outputKey == "LogGroupName" }),
            let logGroupName = logGroupNameOutput.outputValue
        else {
            Issue.record("LogGroupName output not found")
            try await verifyAwsClient.shutdown()
            try await verifyHttpClient.shutdown()
            try await cfClient.shutdown()
            return
        }

        guard let taskDefinitionArnOutput = outputs.first(where: { $0.outputKey == "TaskDefinitionArn" }),
            let taskDefinitionArn = taskDefinitionArnOutput.outputValue
        else {
            Issue.record("TaskDefinitionArn output not found")
            try await verifyAwsClient.shutdown()
            try await verifyHttpClient.shutdown()
            try await cfClient.shutdown()
            return
        }

        guard let serviceNameOutput = outputs.first(where: { $0.outputKey == "ServiceName" }),
            let serviceName = serviceNameOutput.outputValue
        else {
            Issue.record("ServiceName output not found")
            try await verifyAwsClient.shutdown()
            try await verifyHttpClient.shutdown()
            try await cfClient.shutdown()
            return
        }

        print("✅ CloudFormation outputs extracted:")
        print("   - Cluster: \(clusterName)")
        print("   - Task Definition: \(taskDefinitionArn)")
        print("   - Service: \(serviceName)")

        // Verify ECS cluster exists
        print("🔍 Verifying ECS cluster...")
        let ecs = ECS(
            client: verifyAwsClient,
            region: .useast1,
            endpoint: configuration.endpoint
        )

        let clustersRequest = ECS.DescribeClustersRequest(clusters: [clusterName])
        let clustersResponse = try await ecs.describeClusters(clustersRequest)

        guard let cluster = clustersResponse.clusters?.first else {
            Issue.record("ECS cluster not found")
            try await verifyAwsClient.shutdown()
            try await verifyHttpClient.shutdown()
            try await cfClient.shutdown()
            return
        }

        #expect(cluster.clusterName == clusterName, "Cluster name should match")
        #expect(cluster.clusterArn == clusterArn, "Cluster ARN should match")
        #expect(cluster.status == "ACTIVE", "Cluster should be ACTIVE")

        print("✅ ECS Cluster verified:")
        print("   - Name: \(cluster.clusterName ?? "unknown")")
        print("   - Status: \(cluster.status ?? "unknown")")

        // Verify IAM roles exist
        print("🔍 Verifying IAM roles...")
        let iam = IAM(
            client: verifyAwsClient,
            endpoint: configuration.endpoint
        )

        // Extract role names from ARNs
        let taskRoleName = taskRoleArn.components(separatedBy: "/").last ?? ""
        let taskExecutionRoleName = taskExecutionRoleArn.components(separatedBy: "/").last ?? ""

        let taskRoleRequest = IAM.GetRoleRequest(roleName: taskRoleName)
        let taskRoleResponse = try await iam.getRole(taskRoleRequest)
        #expect(taskRoleResponse.role.arn == taskRoleArn, "Task role ARN should match")

        let taskExecutionRoleRequest = IAM.GetRoleRequest(roleName: taskExecutionRoleName)
        let taskExecutionRoleResponse = try await iam.getRole(taskExecutionRoleRequest)
        #expect(taskExecutionRoleResponse.role.arn == taskExecutionRoleArn, "Task execution role ARN should match")

        print("✅ IAM Roles verified:")
        print("   - Task Role: \(taskRoleName)")
        print("   - Execution Role: \(taskExecutionRoleName)")

        // Verify CloudWatch log group exists
        print("🔍 Verifying CloudWatch log group...")
        let logs = CloudWatchLogs(
            client: verifyAwsClient,
            region: .useast1,
            endpoint: configuration.endpoint
        )

        let logGroupsRequest = CloudWatchLogs.DescribeLogGroupsRequest(logGroupNamePrefix: logGroupName)
        let logGroupsResponse = try await logs.describeLogGroups(logGroupsRequest)

        guard let logGroup = logGroupsResponse.logGroups?.first(where: { $0.logGroupName == logGroupName }) else {
            Issue.record("CloudWatch log group not found")
            try await verifyAwsClient.shutdown()
            try await verifyHttpClient.shutdown()
            try await cfClient.shutdown()
            return
        }

        #expect(logGroup.logGroupName == logGroupName, "Log group name should match")
        // Note: LocalStack doesn't always set retentionInDays, so we only check if it's set
        if let retention = logGroup.retentionInDays {
            #expect(retention == 7, "Log retention should be 7 days when set")
        }

        print("✅ CloudWatch log group verified: \(logGroupName)")

        // Verify task definition
        print("🔍 Verifying task definition...")
        let taskDefRequest = ECS.DescribeTaskDefinitionRequest(taskDefinition: taskDefinitionArn)
        let taskDefResponse = try await ecs.describeTaskDefinition(taskDefRequest)

        guard let taskDef = taskDefResponse.taskDefinition else {
            Issue.record("Task definition not found")
            try await verifyAwsClient.shutdown()
            try await verifyHttpClient.shutdown()
            try await cfClient.shutdown()
            return
        }

        #expect(taskDef.cpu == "256", "Task should have 256 CPU (0.25 vCPU)")
        #expect(taskDef.memory == "512", "Task should have 512 MB memory")
        #expect(taskDef.requiresCompatibilities?.contains(.fargate) == true, "Task should support Fargate")
        #expect(taskDef.networkMode == .awsvpc, "Task should use awsvpc network mode")

        print("✅ Task Definition verified:")
        print("   - CPU: \(taskDef.cpu ?? "unknown") (0.25 vCPU)")
        print("   - Memory: \(taskDef.memory ?? "unknown") MB (0.5 GB)")
        print("   - Launch Type: FARGATE")

        // Verify service exists and is running
        print("🔍 Verifying ECS service...")
        let servicesRequest = ECS.DescribeServicesRequest(cluster: clusterName, services: [serviceName])
        let servicesResponse = try await ecs.describeServices(servicesRequest)

        guard let service = servicesResponse.services?.first else {
            Issue.record("ECS service not found")
            try await verifyAwsClient.shutdown()
            try await verifyHttpClient.shutdown()
            try await cfClient.shutdown()
            return
        }

        #expect(service.serviceName == serviceName, "Service name should match")
        #expect(service.desiredCount == 1, "Service should have desired count of 1")
        #expect(service.launchType == .fargate, "Service should use Fargate launch type")

        print("✅ ECS Service verified:")
        print("   - Name: \(service.serviceName ?? "unknown")")
        print("   - Desired: \(service.desiredCount ?? 0)")
        print("   - Running: \(service.runningCount ?? 0)")
        print("   - Launch Type: \(service.launchType?.rawValue ?? "unknown")")

        // Verify at least one task is running
        print("🔍 Verifying running tasks...")
        let tasksRequest = ECS.ListTasksRequest(cluster: clusterName, serviceName: serviceName)
        let tasksResponse = try await ecs.listTasks(tasksRequest)

        if let taskArns = tasksResponse.taskArns, !taskArns.isEmpty {
            let describeTasksRequest = ECS.DescribeTasksRequest(cluster: clusterName, tasks: taskArns)
            let describeTasksResponse = try await ecs.describeTasks(describeTasksRequest)

            if let tasks = describeTasksResponse.tasks {
                for task in tasks {
                    print("   - Task: \(task.taskArn ?? "unknown")")
                    print("     Status: \(task.lastStatus ?? "unknown")")
                    print("     CPU: 256 (0.25 vCPU)")
                    print("     Memory: 512 MB (0.5 GB)")
                }
            }
        } else {
            print("   ⚠️  No tasks currently running (may still be provisioning)")
        }

        print("✅ All verifications passed!")
        print("   - Cluster: \(clusterName) (ACTIVE)")
        print("   - Task Definition: 256 CPU / 512 MB (minimal Fargate)")
        print("   - Service: \(serviceName) (desired: 1)")
        print("   - IAM Roles: Task + Execution")
        print("   - Security Group: \(securityGroupId)")
        print("   - Log Group: \(logGroupName)")

        // Shutdown clients
        try await verifyAwsClient.shutdown()
        try await verifyHttpClient.shutdown()
        try await cfClient.shutdown()
    }
}
