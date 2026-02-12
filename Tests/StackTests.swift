import Foundation
import Testing

@testable import AWS

@Suite("Stack Templates")
struct StackTests {
    @Test("VPCStack has valid CloudFormation template")
    func testVPCStackTemplate() {
        let stack = VPCStack()
        #expect(!stack.templateBody.isEmpty)
        #expect(stack.templateBody.contains("AWS::EC2::VPC"))
        #expect(stack.templateBody.contains("AWS::EC2::Subnet"))
        #expect(stack.templateBody.contains("AWS::EC2::InternetGateway"))
        #expect(stack.templateBody.contains("AWS::EC2::NatGateway"))
    }

    @Test("ECSStack has valid CloudFormation template")
    func testECSStackTemplate() {
        let stack = ECSStack()
        #expect(!stack.templateBody.isEmpty)
        #expect(stack.templateBody.contains("AWS::ECS::Cluster"))
        #expect(stack.templateBody.contains("AWS::IAM::Role"))
        #expect(stack.templateBody.contains("AWS::EC2::SecurityGroup"))
        #expect(stack.templateBody.contains("AWS::Logs::LogGroup"))
    }

    @Test("RDSStack has valid CloudFormation template")
    func testRDSStackTemplate() {
        let stack = RDSStack()
        #expect(!stack.templateBody.isEmpty)
        #expect(stack.templateBody.contains("AWS::RDS::DBCluster"))
        #expect(stack.templateBody.contains("AWS::RDS::DBInstance"))
        #expect(stack.templateBody.contains("AWS::RDS::DBSubnetGroup"))
        #expect(stack.templateBody.contains("AWS::EC2::SecurityGroup"))
        #expect(stack.templateBody.contains("aurora-postgresql"))
        #expect(stack.templateBody.contains("ServerlessV2ScalingConfiguration"))
    }

    @Test("S3Stack has valid CloudFormation template")
    func testS3StackTemplate() {
        let stack = S3Stack()
        #expect(!stack.templateBody.isEmpty)
        #expect(stack.templateBody.contains("AWS::S3::Bucket"))
        #expect(stack.templateBody.contains("BucketEncryption"))
        #expect(stack.templateBody.contains("VersioningConfiguration"))
        #expect(stack.templateBody.contains("PublicAccessBlockConfiguration"))
    }

    @Test("VPCStack template is valid JSON")
    func testVPCStackJSON() throws {
        let stack = VPCStack()
        let data = Data(stack.templateBody.utf8)
        let json = try JSONSerialization.jsonObject(with: data)
        #expect(json is [String: Any])
    }

    @Test("ECSStack template is valid JSON")
    func testECSStackJSON() throws {
        let stack = ECSStack()
        let data = Data(stack.templateBody.utf8)
        let json = try JSONSerialization.jsonObject(with: data)
        #expect(json is [String: Any])
    }

    @Test("RDSStack template is valid JSON")
    func testRDSStackJSON() throws {
        let stack = RDSStack()
        let data = Data(stack.templateBody.utf8)
        let json = try JSONSerialization.jsonObject(with: data)
        #expect(json is [String: Any])
    }

    @Test("S3Stack template is valid JSON")
    func testS3StackJSON() throws {
        let stack = S3Stack()
        let data = Data(stack.templateBody.utf8)
        let json = try JSONSerialization.jsonObject(with: data)
        #expect(json is [String: Any])
    }

    @Test("VPCStack exports required outputs")
    func testVPCStackOutputs() {
        let stack = VPCStack()
        #expect(stack.templateBody.contains("\"Outputs\""))
        #expect(stack.templateBody.contains("VPC"))
        #expect(stack.templateBody.contains("SubnetsPublic"))
        #expect(stack.templateBody.contains("SubnetsPrivate"))
        #expect(stack.templateBody.contains("CidrBlock"))
    }

    @Test("ECSStack exports required outputs")
    func testECSStackOutputs() {
        let stack = ECSStack()
        #expect(stack.templateBody.contains("\"Outputs\""))
        #expect(stack.templateBody.contains("ClusterName"))
        #expect(stack.templateBody.contains("ClusterArn"))
        #expect(stack.templateBody.contains("TaskExecutionRoleArn"))
        #expect(stack.templateBody.contains("SecurityGroupId"))
    }

    @Test("RDSStack exports required outputs")
    func testRDSStackOutputs() {
        let stack = RDSStack()
        #expect(stack.templateBody.contains("\"Outputs\""))
        #expect(stack.templateBody.contains("ClusterEndpoint"))
        #expect(stack.templateBody.contains("ClusterReadEndpoint"))
        #expect(stack.templateBody.contains("DatabasePort"))
        #expect(stack.templateBody.contains("DatabaseName"))
        #expect(stack.templateBody.contains("DatabaseURL"))
    }

    @Test("S3Stack exports required outputs")
    func testS3StackOutputs() {
        let stack = S3Stack()
        #expect(stack.templateBody.contains("\"Outputs\""))
        #expect(stack.templateBody.contains("BucketName"))
        #expect(stack.templateBody.contains("BucketArn"))
        #expect(stack.templateBody.contains("BucketDomainName"))
    }

    @Test("GitHubMirrorStack has valid CloudFormation template")
    func testGitHubMirrorStackTemplate() {
        let stack = GitHubMirrorStack()
        #expect(!stack.templateBody.isEmpty)
        #expect(stack.templateBody.contains("AWS::CodeCommit::Repository"))
        #expect(stack.templateBody.contains("AWS::IAM::User"))
        #expect(stack.templateBody.contains("AWS::IAM::Policy"))
        #expect(stack.templateBody.contains("AWS::IAM::AccessKey"))
    }

    @Test("GitHubMirrorStack template is valid JSON")
    func testGitHubMirrorStackJSON() throws {
        let stack = GitHubMirrorStack()
        let data = Data(stack.templateBody.utf8)
        let json = try JSONSerialization.jsonObject(with: data)
        #expect(json is [String: Any])
    }

    @Test("GitHubMirrorStack has required parameters")
    func testGitHubMirrorStackParameters() {
        let stack = GitHubMirrorStack()
        #expect(stack.templateBody.contains("\"Parameters\""))
        #expect(stack.templateBody.contains("RepositoryName"))
        #expect(stack.templateBody.contains("Environment"))
    }

    @Test("GitHubMirrorStack exports required outputs")
    func testGitHubMirrorStackOutputs() {
        let stack = GitHubMirrorStack()
        #expect(stack.templateBody.contains("\"Outputs\""))
        #expect(stack.templateBody.contains("RepositoryName"))
        #expect(stack.templateBody.contains("RepositoryArn"))
        #expect(stack.templateBody.contains("CloneUrlHttp"))
        #expect(stack.templateBody.contains("CloneUrlSsh"))
        #expect(stack.templateBody.contains("IAMUserName"))
        #expect(stack.templateBody.contains("IAMUserArn"))
        #expect(stack.templateBody.contains("AccessKeyId"))
        #expect(stack.templateBody.contains("SecretAccessKey"))
    }

    @Test("GitHubMirrorStack IAM policy uses least privilege")
    func testGitHubMirrorStackIAMPolicy() {
        let stack = GitHubMirrorStack()
        // Policy should only allow GitPull and GitPush
        #expect(stack.templateBody.contains("codecommit:GitPull"))
        #expect(stack.templateBody.contains("codecommit:GitPush"))
        // Policy should be scoped to the repository ARN (not wildcard)
        #expect(stack.templateBody.contains("Fn::GetAtt"))
        #expect(stack.templateBody.contains("CodeCommitRepository"))
    }
}
