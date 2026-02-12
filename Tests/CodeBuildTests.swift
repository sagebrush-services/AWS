import AsyncHTTPClient
import Foundation
import SotoCloudFormation
import SotoCodeBuild
import SotoCore
import SotoIAM
import Testing

@testable import AWS

@Suite("CodeBuild Stack Tests")
struct CodeBuildTests {
    @Test("CodeBuildStack template is valid JSON")
    func testTemplateIsValidJSON() {
        let stack = CodeBuildStack()
        let data = Data(stack.templateBody.utf8)

        // Verify it's valid JSON
        let json = try? JSONSerialization.jsonObject(with: data)
        #expect(json != nil, "Template should be valid JSON")

        // Verify it's a dictionary (object)
        #expect(json is [String: Any], "Template should be a JSON object")
    }

    @Test("CodeBuildStack has valid CloudFormation template")
    func testTemplateStructure() throws {
        let stack = CodeBuildStack()
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
            "CodeBuildServiceRole",
            "CodeBuildProject",
        ]

        for resourceName in expectedResources {
            #expect(resources[resourceName] != nil, "Should have resource: \(resourceName)")
        }
    }

    @Test("CodeBuildStack exports required outputs")
    func testOutputs() throws {
        let stack = CodeBuildStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let outputs = template["Outputs"] as? [String: Any]
        else {
            Issue.record("Template should have Outputs section")
            return
        }

        let expectedOutputs = [
            "ProjectName",
            "ProjectArn",
            "ServiceRoleArn",
        ]

        for outputName in expectedOutputs {
            #expect(outputs[outputName] != nil, "Should have output: \(outputName)")
        }
    }

    @Test("CodeBuildStack IAM role has correct policies")
    func testIAMPolicies() throws {
        let stack = CodeBuildStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let resources = template["Resources"] as? [String: Any],
            let role = resources["CodeBuildServiceRole"] as? [String: Any],
            let properties = role["Properties"] as? [String: Any],
            let policies = properties["Policies"] as? [[String: Any]]
        else {
            Issue.record("Could not parse IAM role policies")
            return
        }

        // Verify expected policies exist
        let policyNames = policies.compactMap { $0["PolicyName"] as? String }
        let expectedPolicies = [
            "CodeBuildBasePolicy",
            "CodeCommitReadPolicy",
            "S3ArtifactPolicy",
            "LambdaUpdatePolicy",
            "LambdaInvokePolicy",
        ]

        for expectedPolicy in expectedPolicies {
            #expect(
                policyNames.contains(expectedPolicy),
                "Should have policy: \(expectedPolicy)"
            )
        }

        // Verify least privilege: CodeCommit should only have GitPull
        if let codeCommitPolicy = policies.first(where: {
            $0["PolicyName"] as? String == "CodeCommitReadPolicy"
        }),
            let policyDoc = codeCommitPolicy["PolicyDocument"] as? [String: Any],
            let statements = policyDoc["Statement"] as? [[String: Any]],
            let firstStatement = statements.first,
            let actions = firstStatement["Action"] as? [String]
        {
            #expect(actions == ["codecommit:GitPull"], "CodeCommit policy should only allow GitPull")
        }

        // Verify Lambda policy has correct actions
        if let lambdaUpdatePolicy = policies.first(where: {
            $0["PolicyName"] as? String == "LambdaUpdatePolicy"
        }),
            let policyDoc = lambdaUpdatePolicy["PolicyDocument"] as? [String: Any],
            let statements = policyDoc["Statement"] as? [[String: Any]],
            let firstStatement = statements.first,
            let actions = firstStatement["Action"] as? [String]
        {
            #expect(
                actions.contains("lambda:UpdateFunctionCode"),
                "Lambda policy should allow UpdateFunctionCode"
            )
            #expect(
                actions.contains("lambda:GetFunction"),
                "Lambda policy should allow GetFunction"
            )
        }
    }

    @Test("CodeBuildStack uses ARM64 architecture")
    func testARM64Architecture() throws {
        let stack = CodeBuildStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let resources = template["Resources"] as? [String: Any],
            let project = resources["CodeBuildProject"] as? [String: Any],
            let properties = project["Properties"] as? [String: Any],
            let environment = properties["Environment"] as? [String: Any],
            let environmentType = environment["Type"] as? String
        else {
            Issue.record("Could not parse CodeBuild environment")
            return
        }

        #expect(environmentType == "ARM_CONTAINER", "Should use ARM_CONTAINER environment type")
    }

    @Test("CodeBuildStack has required environment variables")
    func testEnvironmentVariables() throws {
        let stack = CodeBuildStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let resources = template["Resources"] as? [String: Any],
            let project = resources["CodeBuildProject"] as? [String: Any],
            let properties = project["Properties"] as? [String: Any],
            let environment = properties["Environment"] as? [String: Any],
            let envVars = environment["EnvironmentVariables"] as? [[String: Any]]
        else {
            Issue.record("Could not parse environment variables")
            return
        }

        let varNames = envVars.compactMap { $0["Name"] as? String }
        let expectedVars = [
            "S3_BUCKET",
            "LAMBDA_FUNCTION_NAME",
            "AWS_REGION",
        ]

        for expectedVar in expectedVars {
            #expect(varNames.contains(expectedVar), "Should have environment variable: \(expectedVar)")
        }
    }
}
