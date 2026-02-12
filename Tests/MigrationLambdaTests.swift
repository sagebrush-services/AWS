import AsyncHTTPClient
import Foundation
import SotoCloudFormation
import SotoCore
import SotoIAM
import SotoLambda
import Testing

@testable import AWS

@Suite("Migration Lambda Stack Tests")
struct MigrationLambdaTests {
    @Test("MigrationLambdaStack template is valid JSON")
    func testTemplateIsValidJSON() {
        let stack = MigrationLambdaStack()
        let data = Data(stack.templateBody.utf8)

        // Verify it's valid JSON
        let json = try? JSONSerialization.jsonObject(with: data)
        #expect(json != nil, "Template should be valid JSON")

        // Verify it's a dictionary (object)
        #expect(json is [String: Any], "Template should be a JSON object")
    }

    @Test("MigrationLambdaStack has valid CloudFormation template")
    func testTemplateStructure() throws {
        let stack = MigrationLambdaStack()
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
            "LambdaSecurityGroup",
            "LambdaExecutionRole",
            "LambdaFunction",
            "LambdaLogGroup",
        ]

        for resourceName in expectedResources {
            #expect(resources[resourceName] != nil, "Should have resource: \(resourceName)")
        }
    }

    @Test("MigrationLambdaStack exports required outputs")
    func testOutputs() throws {
        let stack = MigrationLambdaStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let outputs = template["Outputs"] as? [String: Any]
        else {
            Issue.record("Template should have Outputs section")
            return
        }

        let expectedOutputs = [
            "FunctionName",
            "FunctionArn",
            "ExecutionRoleArn",
            "SecurityGroupId",
            "LogGroupName",
        ]

        for outputName in expectedOutputs {
            #expect(outputs[outputName] != nil, "Should have output: \(outputName)")
        }
    }

    @Test("MigrationLambdaStack Lambda function uses ARM64 architecture")
    func testARM64Architecture() throws {
        let stack = MigrationLambdaStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let resources = template["Resources"] as? [String: Any],
            let function = resources["LambdaFunction"] as? [String: Any],
            let properties = function["Properties"] as? [String: Any],
            let architectures = properties["Architectures"] as? [String]
        else {
            Issue.record("Could not parse Lambda function architectures")
            return
        }

        #expect(architectures == ["arm64"], "Lambda should use arm64 architecture")
    }

    @Test("MigrationLambdaStack Lambda function uses custom runtime")
    func testCustomRuntime() throws {
        let stack = MigrationLambdaStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let resources = template["Resources"] as? [String: Any],
            let function = resources["LambdaFunction"] as? [String: Any],
            let properties = function["Properties"] as? [String: Any],
            let runtime = properties["Runtime"] as? String
        else {
            Issue.record("Could not parse Lambda runtime")
            return
        }

        #expect(runtime == "provided.al2023", "Lambda should use provided.al2023 runtime for Swift")
    }

    @Test("MigrationLambdaStack Lambda function has VPC configuration")
    func testVPCConfiguration() throws {
        let stack = MigrationLambdaStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let resources = template["Resources"] as? [String: Any],
            let function = resources["LambdaFunction"] as? [String: Any],
            let properties = function["Properties"] as? [String: Any],
            let vpcConfig = properties["VpcConfig"] as? [String: Any]
        else {
            Issue.record("Could not parse VPC configuration")
            return
        }

        #expect(vpcConfig["SubnetIds"] != nil, "Should have SubnetIds")
        #expect(vpcConfig["SecurityGroupIds"] != nil, "Should have SecurityGroupIds")
    }

    @Test("MigrationLambdaStack Lambda function has required environment variables")
    func testEnvironmentVariables() throws {
        let stack = MigrationLambdaStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let resources = template["Resources"] as? [String: Any],
            let function = resources["LambdaFunction"] as? [String: Any],
            let properties = function["Properties"] as? [String: Any],
            let environment = properties["Environment"] as? [String: Any],
            let variables = environment["Variables"] as? [String: Any]
        else {
            Issue.record("Could not parse environment variables")
            return
        }

        let expectedVars = [
            "DATABASE_HOST",
            "DATABASE_PORT",
            "DATABASE_NAME",
            "DATABASE_SECRET_ARN",
        ]

        for expectedVar in expectedVars {
            #expect(variables[expectedVar] != nil, "Should have environment variable: \(expectedVar)")
        }
    }

    @Test("MigrationLambdaStack IAM role has VPC execution policy")
    func testVPCExecutionPolicy() throws {
        let stack = MigrationLambdaStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let resources = template["Resources"] as? [String: Any],
            let role = resources["LambdaExecutionRole"] as? [String: Any],
            let properties = role["Properties"] as? [String: Any],
            let managedPolicies = properties["ManagedPolicyArns"] as? [String]
        else {
            Issue.record("Could not parse IAM role managed policies")
            return
        }

        #expect(
            managedPolicies.contains("arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"),
            "Should have VPC execution policy"
        )
    }

    @Test("MigrationLambdaStack IAM role has Secrets Manager read permissions")
    func testSecretsManagerPermissions() throws {
        let stack = MigrationLambdaStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let resources = template["Resources"] as? [String: Any],
            let role = resources["LambdaExecutionRole"] as? [String: Any],
            let properties = role["Properties"] as? [String: Any],
            let policies = properties["Policies"] as? [[String: Any]]
        else {
            Issue.record("Could not parse IAM role policies")
            return
        }

        // Verify SecretsManagerReadPolicy exists
        guard
            let secretsPolicy = policies.first(where: {
                $0["PolicyName"] as? String == "SecretsManagerReadPolicy"
            }),
            let policyDoc = secretsPolicy["PolicyDocument"] as? [String: Any],
            let statements = policyDoc["Statement"] as? [[String: Any]],
            let firstStatement = statements.first,
            let actions = firstStatement["Action"] as? [String]
        else {
            Issue.record("Could not parse Secrets Manager policy")
            return
        }

        // Verify only read permissions (least privilege)
        #expect(
            actions.contains("secretsmanager:GetSecretValue"),
            "Should allow GetSecretValue"
        )
        #expect(
            actions.contains("secretsmanager:DescribeSecret"),
            "Should allow DescribeSecret"
        )
        #expect(actions.count == 2, "Should only have read permissions (least privilege)")
    }

    @Test("MigrationLambdaStack security group allows Aurora access")
    func testSecurityGroupConfiguration() throws {
        let stack = MigrationLambdaStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let resources = template["Resources"] as? [String: Any],
            let securityGroup = resources["LambdaSecurityGroup"] as? [String: Any],
            let properties = securityGroup["Properties"] as? [String: Any],
            let egressRules = properties["SecurityGroupEgress"] as? [[String: Any]]
        else {
            Issue.record("Could not parse security group")
            return
        }

        // Verify PostgreSQL egress rule exists
        let postgresRule = egressRules.first { rule in
            (rule["FromPort"] as? Int) == 5432 && (rule["ToPort"] as? Int) == 5432
        }
        #expect(postgresRule != nil, "Should have PostgreSQL egress rule on port 5432")

        // Verify HTTPS egress rule for AWS API calls
        let httpsRule = egressRules.first { rule in
            (rule["FromPort"] as? Int) == 443 && (rule["ToPort"] as? Int) == 443
        }
        #expect(httpsRule != nil, "Should have HTTPS egress rule for AWS API calls")
    }

    @Test("MigrationLambdaStack has appropriate timeout and memory")
    func testLambdaConfiguration() throws {
        let stack = MigrationLambdaStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let resources = template["Resources"] as? [String: Any],
            let function = resources["LambdaFunction"] as? [String: Any],
            let properties = function["Properties"] as? [String: Any]
        else {
            Issue.record("Could not parse Lambda function properties")
            return
        }

        // Verify timeout is sufficient for migrations (5 minutes)
        if let timeout = properties["Timeout"] as? Int {
            #expect(timeout >= 300, "Timeout should be at least 300 seconds for migrations")
        }

        // Verify memory is sufficient for Swift runtime
        if let memory = properties["MemorySize"] as? Int {
            #expect(memory >= 512, "Memory should be at least 512 MB for Swift runtime")
        }
    }

    @Test("MigrationLambdaStack has default VPC stack parameter")
    func testDefaultVPCStackParameter() throws {
        let stack = MigrationLambdaStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let parameters = template["Parameters"] as? [String: Any],
            let vpcStackParam = parameters["VPCStackName"] as? [String: Any],
            let defaultValue = vpcStackParam["Default"] as? String
        else {
            Issue.record("Could not parse VPCStackName parameter")
            return
        }

        #expect(defaultValue == "oregon-vpc", "Default VPC stack should be oregon-vpc")
    }
}
