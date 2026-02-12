import AsyncHTTPClient
import Foundation
import SotoCloudFormation
import SotoCore
import SotoRDS
import Testing

@testable import AWS

@Suite("RDS Stack Tests")
struct RDSTests {
    /// Test RDS stack verification after CLI creation
    @Test("Verify Aurora Serverless v2 stack and resources in LocalStack")
    func testVerifyRDSStack() async throws {
        let configuration = AWSConfiguration()
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)

        // Use the existing stack created manually
        let stackName = "dev-rds"

        // Create AWS client for LocalStack
        let awsClient = SotoCore.AWSClient(
            httpClient: httpClient
        )

        // Verify CloudFormation stack exists
        print("🔍 Verifying CloudFormation stack...")
        let cloudFormation = CloudFormation(
            client: awsClient,
            region: .useast1,
            endpoint: configuration.endpoint
        )

        let describeRequest = CloudFormation.DescribeStacksInput(stackName: stackName)
        let stackResponse = try await cloudFormation.describeStacks(describeRequest)

        guard let stack = stackResponse.stacks?.first else {
            Issue.record("CloudFormation stack not found")
            return
        }

        #expect(stack.stackName == stackName, "Stack name should match")
        #expect(stack.stackStatus == .createComplete, "Stack should be in CREATE_COMPLETE state")

        // Extract cluster information from stack outputs
        guard let outputs = stack.outputs else {
            Issue.record("Stack has no outputs")
            return
        }

        guard let clusterEndpointOutput = outputs.first(where: { $0.outputKey == "ClusterEndpoint" }),
            let clusterEndpoint = clusterEndpointOutput.outputValue
        else {
            Issue.record("ClusterEndpoint output not found")
            return
        }

        guard let portOutput = outputs.first(where: { $0.outputKey == "DatabasePort" }),
            let port = portOutput.outputValue
        else {
            Issue.record("DatabasePort output not found")
            return
        }

        guard let dbNameOutput = outputs.first(where: { $0.outputKey == "DatabaseName" }),
            let dbName = dbNameOutput.outputValue
        else {
            Issue.record("DatabaseName output not found")
            return
        }

        guard let dbUrlOutput = outputs.first(where: { $0.outputKey == "DatabaseURL" }),
            let dbUrl = dbUrlOutput.outputValue
        else {
            Issue.record("DatabaseURL output not found")
            return
        }

        #expect(!port.isEmpty, "Port should not be empty")
        #expect(dbName == "app", "Database name should be 'app' (default)")
        #expect(dbUrl.contains("postgresql://"), "Database URL should be a PostgreSQL connection string")

        print("✅ Cluster Endpoint: \(clusterEndpoint)")
        print("✅ Port: \(port)")
        print("✅ Database Name: \(dbName)")

        // Verify Aurora cluster exists in RDS
        print("🔍 Verifying Aurora cluster in RDS...")
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
        #expect(cluster.engineMode == "provisioned", "Engine mode should be provisioned for Serverless v2")
        #expect(cluster.status == "available", "Cluster should be available")

        // Verify Serverless v2 scaling configuration
        guard let scalingConfig = cluster.serverlessV2ScalingConfiguration else {
            Issue.record("Serverless v2 scaling configuration not found")
            return
        }

        #expect(scalingConfig.minCapacity == 0.5, "Min capacity should be 0.5 ACU")
        #expect(scalingConfig.maxCapacity == 1.0, "Max capacity should be 1.0 ACU")

        print(
            "✅ Aurora Serverless v2 scaling: min=\(scalingConfig.minCapacity ?? 0) ACU, max=\(scalingConfig.maxCapacity ?? 0) ACU"
        )

        // Verify database instance
        print("🔍 Verifying database instance...")
        let instanceIdentifier = "\(stackName)-instance"
        let instancesRequest = RDS.DescribeDBInstancesMessage(
            dbInstanceIdentifier: instanceIdentifier
        )
        let instancesResponse = try await rds.describeDBInstances(instancesRequest)

        guard let instance = instancesResponse.dbInstances?.first else {
            Issue.record("Database instance not found")
            return
        }

        #expect(instance.dbInstanceIdentifier == instanceIdentifier, "Instance identifier should match")
        #expect(instance.dbClusterIdentifier == clusterIdentifier, "Instance should be part of the cluster")
        #expect(instance.dbInstanceClass == "db.serverless", "Instance class should be db.serverless")
        #expect(instance.engine == "aurora-postgresql", "Engine should be aurora-postgresql")
        #expect(instance.dbInstanceStatus == "available", "Instance should be available")

        // Verify cluster has correct VPC configuration
        #expect(cluster.dbSubnetGroup != nil, "Cluster should have a subnet group")
        #expect(cluster.vpcSecurityGroups?.isEmpty == false, "Cluster should have security groups")

        print("✅ All verifications passed!")
        print("   - Cluster: \(clusterIdentifier)")
        print("   - Instance: \(instanceIdentifier)")
        print("   - Engine: \(cluster.engine ?? "unknown") \(cluster.engineVersion ?? "unknown")")
        print("   - Serverless v2: Yes")
        print("   - Database: \(dbName)")

        // Shutdown clients
        try await awsClient.shutdown()
        try await httpClient.shutdown()
    }
}
