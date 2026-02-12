import AsyncHTTPClient
import Foundation
import SotoCloudFormation
import SotoCore
import SotoIAM
import Testing

@testable import AWS

@Suite("GitHub OIDC Stack Tests")
struct GitHubOIDCTests {
    @Test("GitHubOIDCStack template is valid JSON")
    func testTemplateIsValidJSON() {
        let stack = GitHubOIDCStack()
        let data = Data(stack.templateBody.utf8)

        // Verify it's valid JSON
        let json = try? JSONSerialization.jsonObject(with: data)
        #expect(json != nil, "Template should be valid JSON")

        // Verify it's a dictionary (object)
        #expect(json is [String: Any], "Template should be a JSON object")
    }

    @Test("GitHubOIDCStack has valid CloudFormation template")
    func testTemplateStructure() throws {
        let stack = GitHubOIDCStack()
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
            "GitHubOIDCProvider",
            "GitHubActionsRole",
        ]

        for resourceName in expectedResources {
            #expect(resources[resourceName] != nil, "Should have resource: \(resourceName)")
        }
    }

    @Test("GitHubOIDCStack exports required outputs")
    func testOutputs() throws {
        let stack = GitHubOIDCStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let outputs = template["Outputs"] as? [String: Any]
        else {
            Issue.record("Template should have Outputs section")
            return
        }

        let expectedOutputs = [
            "OIDCProviderArn",
            "GitHubActionsRoleArn",
            "GitHubActionsRoleName",
        ]

        for outputName in expectedOutputs {
            #expect(outputs[outputName] != nil, "Should have output: \(outputName)")
        }
    }

    @Test("GitHubOIDCStack OIDC provider has correct configuration")
    func testOIDCProviderConfiguration() throws {
        let stack = GitHubOIDCStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let resources = template["Resources"] as? [String: Any],
            let provider = resources["GitHubOIDCProvider"] as? [String: Any],
            let properties = provider["Properties"] as? [String: Any]
        else {
            Issue.record("Could not parse OIDC provider")
            return
        }

        // Verify URL
        #expect(
            properties["Url"] as? String == "https://token.actions.githubusercontent.com",
            "OIDC provider URL should be GitHub Actions"
        )

        // Verify client ID
        guard let clientIds = properties["ClientIdList"] as? [String] else {
            Issue.record("ClientIdList should be an array")
            return
        }
        #expect(clientIds.contains("sts.amazonaws.com"), "Should have sts.amazonaws.com client ID")

        // Verify thumbprints exist
        guard let thumbprints = properties["ThumbprintList"] as? [String] else {
            Issue.record("ThumbprintList should be an array")
            return
        }
        #expect(thumbprints.count > 0, "Should have at least one thumbprint")
    }

    @Test("GitHubOIDCStack IAM role has correct trust policy")
    func testIAMRoleTrustPolicy() throws {
        let stack = GitHubOIDCStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let resources = template["Resources"] as? [String: Any],
            let role = resources["GitHubActionsRole"] as? [String: Any],
            let properties = role["Properties"] as? [String: Any],
            let assumeRolePolicy = properties["AssumeRolePolicyDocument"] as? [String: Any],
            let statements = assumeRolePolicy["Statement"] as? [[String: Any]],
            let firstStatement = statements.first
        else {
            Issue.record("Could not parse IAM role trust policy")
            return
        }

        // Verify the action is AssumeRoleWithWebIdentity
        #expect(
            firstStatement["Action"] as? String == "sts:AssumeRoleWithWebIdentity",
            "Should use AssumeRoleWithWebIdentity action"
        )

        // Verify the principal is the OIDC provider
        guard let principal = firstStatement["Principal"] as? [String: Any],
            let federated = principal["Federated"] as? [String: String]
        else {
            Issue.record("Could not parse principal")
            return
        }

        #expect(federated["Ref"] != nil, "Should reference OIDC provider")

        // Verify conditions restrict to specific repository
        guard let condition = firstStatement["Condition"] as? [String: Any] else {
            Issue.record("Should have conditions on trust policy")
            return
        }

        #expect(condition["StringEquals"] != nil, "Should have StringEquals condition")
        #expect(condition["StringLike"] != nil, "Should have StringLike condition for repo")
    }

    @Test("GitHubOIDCStack IAM role has minimal permissions (least privilege)")
    func testIAMRolePermissions() throws {
        let stack = GitHubOIDCStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let resources = template["Resources"] as? [String: Any],
            let role = resources["GitHubActionsRole"] as? [String: Any],
            let properties = role["Properties"] as? [String: Any],
            let policies = properties["Policies"] as? [[String: Any]]
        else {
            Issue.record("Could not parse IAM role policies")
            return
        }

        // Verify only one policy exists
        #expect(policies.count == 1, "Should have exactly one inline policy")

        // Verify policy name
        guard let policy = policies.first,
            let policyName = policy["PolicyName"] as? String
        else {
            Issue.record("Could not parse policy")
            return
        }

        #expect(
            policyName == "CodeCommitPushPullPolicy",
            "Policy should be CodeCommitPushPullPolicy"
        )

        // Verify only GitPull and GitPush actions
        guard let policyDoc = policy["PolicyDocument"] as? [String: Any],
            let statements = policyDoc["Statement"] as? [[String: Any]],
            let firstStatement = statements.first,
            let actions = firstStatement["Action"] as? [String]
        else {
            Issue.record("Could not parse policy actions")
            return
        }

        #expect(actions.count == 2, "Should have exactly 2 actions (least privilege)")
        #expect(actions.contains("codecommit:GitPull"), "Should allow GitPull")
        #expect(actions.contains("codecommit:GitPush"), "Should allow GitPush")
    }

    @Test("GitHubOIDCStack has default parameters for neon-law-foundation/SagebrushStandards")
    func testDefaultParameters() throws {
        let stack = GitHubOIDCStack()
        let data = Data(stack.templateBody.utf8)

        guard let template = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let parameters = template["Parameters"] as? [String: Any]
        else {
            Issue.record("Could not parse parameters")
            return
        }

        // Verify GitHubOrganization default
        if let orgParam = parameters["GitHubOrganization"] as? [String: Any],
            let defaultValue = orgParam["Default"] as? String
        {
            #expect(defaultValue == "NeonLawFoundation", "Default organization should be NeonLawFoundation")
        }

        // Verify GitHubRepository default
        if let repoParam = parameters["GitHubRepository"] as? [String: Any],
            let defaultValue = repoParam["Default"] as? String
        {
            #expect(defaultValue == "Standards", "Default repository should be Standards")
        }
    }
}
