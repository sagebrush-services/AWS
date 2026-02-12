import AsyncHTTPClient
import Foundation
import SotoCloudFormation
import SotoCore
import SotoEC2
import Testing

@testable import AWS

@Suite("VPC Stack Tests")
struct VPCTests {
    /// Test VPC stack verification after CLI creation
    @Test("Verify VPC stack and resources in LocalStack")
    func testVerifyVPCStack() async throws {
        let configuration = AWSConfiguration()
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)

        // Use the existing stack created manually
        let stackName = "dev-vpc"

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

        // Extract VPC ID from stack outputs
        guard let outputs = stack.outputs else {
            Issue.record("Stack has no outputs")
            return
        }

        guard let vpcOutput = outputs.first(where: { $0.outputKey == "VPC" }),
            let vpcId = vpcOutput.outputValue
        else {
            Issue.record("VPC output not found")
            return
        }

        guard let cidrOutput = outputs.first(where: { $0.outputKey == "CidrBlock" }),
            let cidrBlock = cidrOutput.outputValue
        else {
            Issue.record("CidrBlock output not found")
            return
        }

        #expect(cidrBlock == "10.10.0.0/16", "CIDR block should match ClassB parameter (10)")

        print("✅ VPC ID: \(vpcId)")
        print("✅ CIDR: \(cidrBlock)")

        // Verify VPC exists in EC2
        print("🔍 Verifying VPC in EC2...")
        let ec2 = EC2(
            client: awsClient,
            region: .useast1,
            endpoint: configuration.endpoint
        )

        let vpcRequest = EC2.DescribeVpcsRequest(vpcIds: [vpcId])
        let vpcResponse = try await ec2.describeVpcs(vpcRequest)

        guard let vpc = vpcResponse.vpcs?.first else {
            Issue.record("VPC not found in EC2")
            return
        }

        #expect(vpc.vpcId == vpcId, "VPC ID should match")
        #expect(vpc.cidrBlock == "10.10.0.0/16", "VPC CIDR should match")
        #expect(vpc.state == .available, "VPC should be available")

        // Verify subnets exist
        print("🔍 Verifying subnets...")
        let subnetRequest = EC2.DescribeSubnetsRequest(
            filters: [
                EC2.Filter(name: "vpc-id", values: [vpcId])
            ]
        )
        let subnetResponse = try await ec2.describeSubnets(subnetRequest)

        guard let subnets = subnetResponse.subnets else {
            Issue.record("No subnets found")
            return
        }

        #expect(subnets.count == 4, "Should have 4 subnets (2 public, 2 private)")

        // Verify we have public and private subnets
        let publicSubnets = subnets.filter { subnet in
            subnet.tags?.contains(where: { $0.value?.contains("public") == true }) == true
        }

        let privateSubnets = subnets.filter { subnet in
            subnet.tags?.contains(where: { $0.value?.contains("private") == true }) == true
        }

        #expect(publicSubnets.count == 2, "Should have 2 public subnets")
        #expect(privateSubnets.count == 2, "Should have 2 private subnets")

        // Verify subnets are in different availability zones
        let publicAZs = Set(publicSubnets.compactMap { $0.availabilityZone })
        let privateAZs = Set(privateSubnets.compactMap { $0.availabilityZone })

        #expect(publicAZs.count == 2, "Public subnets should be in 2 different AZs")
        #expect(privateAZs.count == 2, "Private subnets should be in 2 different AZs")

        print("✅ All verifications passed!")
        print("   - VPC: \(vpcId)")
        print("   - CIDR: \(cidrBlock)")
        print("   - Public subnets: \(publicSubnets.count)")
        print("   - Private subnets: \(privateSubnets.count)")

        // Shutdown clients
        try await awsClient.shutdown()
        try await httpClient.shutdown()
    }
}
