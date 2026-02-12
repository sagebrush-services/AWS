import Foundation

/// CloudFormation stack for creating a Service Control Policy (SCP)
/// that restricts AWS API calls to specific regions
///
/// NOTE: This must be deployed to the Management account (731099197338)
/// After creation, the policy must be attached to accounts or OUs separately
struct SCPStack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "Service Control Policy to restrict AWS regions",
          "Parameters": {
            "PolicyName": {
              "Description": "Name of the Service Control Policy",
              "Type": "String",
              "Default": "RestrictRegions"
            },
            "PolicyDescription": {
              "Description": "Description of the Service Control Policy",
              "Type": "String",
              "Default": "Restricts AWS API calls to us-west-2 and us-east-1 only"
            },
            "AllowedRegion1": {
              "Description": "First allowed AWS region",
              "Type": "String",
              "Default": "us-west-2",
              "AllowedValues": [
                "us-east-1", "us-east-2", "us-west-1", "us-west-2",
                "eu-west-1", "eu-west-2", "eu-west-3", "eu-central-1",
                "ap-southeast-1", "ap-southeast-2", "ap-northeast-1"
              ]
            },
            "AllowedRegion2": {
              "Description": "Second allowed AWS region",
              "Type": "String",
              "Default": "us-east-1",
              "AllowedValues": [
                "us-east-1", "us-east-2", "us-west-1", "us-west-2",
                "eu-west-1", "eu-west-2", "eu-west-3", "eu-central-1",
                "ap-southeast-1", "ap-southeast-2", "ap-northeast-1"
              ]
            },
            "TargetAccountId": {
              "Description": "AWS account ID to attach this SCP to (optional - can be attached manually)",
              "Type": "String",
              "Default": "",
              "AllowedPattern": "^$|^[0-9]{12}$",
              "ConstraintDescription": "Must be empty or a valid 12-digit AWS account ID"
            }
          },
          "Conditions": {
            "HasTargetAccount": {
              "Fn::Not": [
                { "Fn::Equals": [{ "Ref": "TargetAccountId" }, ""] }
              ]
            }
          },
          "Resources": {
            "RegionRestrictionPolicy": {
              "Type": "AWS::Organizations::Policy",
              "Properties": {
                "Name": { "Ref": "PolicyName" },
                "Description": { "Ref": "PolicyDescription" },
                "Type": "SERVICE_CONTROL_POLICY",
                "Content": {
                  "Fn::Sub": [
                    "{\\"Version\\":\\"2012-10-17\\",\\"Statement\\":[{\\"Sid\\":\\"DenyAllOutsideAllowedRegions\\",\\"Effect\\":\\"Deny\\",\\"NotAction\\":[\\"a4b:*\\",\\"budgets:*\\",\\"ce:*\\",\\"chime:*\\",\\"cloudfront:*\\",\\"globalaccelerator:*\\",\\"health:*\\",\\"iam:*\\",\\"importexport:*\\",\\"organizations:*\\",\\"route53:*\\",\\"route53domains:*\\",\\"shield:*\\",\\"sts:*\\",\\"support:*\\",\\"trustedadvisor:*\\",\\"waf:*\\",\\"waf-regional:*\\",\\"wafv2:*\\"],\\"Resource\\":\\"*\\",\\"Condition\\":{\\"StringNotEquals\\":{\\"aws:RequestedRegion\\":[\\"${Region1}\\",\\"${Region2}\\"]}}}]}",
                    {
                      "Region1": { "Ref": "AllowedRegion1" },
                      "Region2": { "Ref": "AllowedRegion2" }
                    }
                  ]
                },
                "TargetIds": {
                  "Fn::If": [
                    "HasTargetAccount",
                    [{ "Ref": "TargetAccountId" }],
                    { "Ref": "AWS::NoValue" }
                  ]
                }
              }
            }
          },
          "Outputs": {
            "PolicyId": {
              "Description": "ID of the Service Control Policy",
              "Value": { "Ref": "RegionRestrictionPolicy" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-PolicyId" }
              }
            },
            "PolicyName": {
              "Description": "Name of the Service Control Policy",
              "Value": { "Ref": "PolicyName" }
            },
            "AllowedRegions": {
              "Description": "Allowed AWS regions",
              "Value": {
                "Fn::Sub": "${AllowedRegion1}, ${AllowedRegion2}"
              }
            },
            "AttachCommand": {
              "Description": "AWS CLI command to attach this policy to an account",
              "Value": {
                "Fn::Sub": "aws organizations attach-policy --policy-id ${RegionRestrictionPolicy} --target-id <account-id>"
              }
            }
          }
        }
        """
}
