import Foundation

/// CloudFormation stack for creating cross-account console access role in target accounts
struct ConsoleAccessRoleStack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "Cross-account IAM role for AWS Console access via role switching",
          "Parameters": {
            "ManagementAccountId": {
              "Type": "String",
              "Description": "AWS Account ID of the management account that will assume this role",
              "Default": "731099197338",
              "AllowedPattern": "^[0-9]{12}$",
              "ConstraintDescription": "Must be a 12-digit AWS account ID"
            },
            "RoleName": {
              "Type": "String",
              "Description": "Name of the IAM role to create",
              "Default": "ConsoleAdminAccess",
              "AllowedPattern": "^[\\\\w+=,.@-]+$",
              "ConstraintDescription": "Must be a valid IAM role name"
            },
            "PermissionLevel": {
              "Type": "String",
              "Description": "Permission level for the role",
              "Default": "Administrator",
              "AllowedValues": ["Administrator", "PowerUser", "ReadOnly"]
            },
            "MaxSessionDuration": {
              "Type": "Number",
              "Description": "Maximum session duration in seconds (1 hour to 12 hours)",
              "Default": 3600,
              "MinValue": 3600,
              "MaxValue": 43200
            }
          },
          "Conditions": {
            "UseAdministratorAccess": {
              "Fn::Equals": [{ "Ref": "PermissionLevel" }, "Administrator"]
            },
            "UsePowerUserAccess": {
              "Fn::Equals": [{ "Ref": "PermissionLevel" }, "PowerUser"]
            },
            "UseReadOnlyAccess": {
              "Fn::Equals": [{ "Ref": "PermissionLevel" }, "ReadOnly"]
            }
          },
          "Resources": {
            "ConsoleAccessRole": {
              "Type": "AWS::IAM::Role",
              "Properties": {
                "RoleName": { "Ref": "RoleName" },
                "Description": {
                  "Fn::Sub": "Cross-account console access role for ${ManagementAccountId}"
                },
                "MaxSessionDuration": { "Ref": "MaxSessionDuration" },
                "AssumeRolePolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Principal": {
                        "AWS": { "Fn::Sub": "arn:aws:iam::${ManagementAccountId}:root" }
                      },
                      "Action": "sts:AssumeRole"
                    }
                  ]
                },
                "ManagedPolicyArns": [
                  {
                    "Fn::If": [
                      "UseAdministratorAccess",
                      "arn:aws:iam::aws:policy/AdministratorAccess",
                      { "Ref": "AWS::NoValue" }
                    ]
                  },
                  {
                    "Fn::If": [
                      "UsePowerUserAccess",
                      "arn:aws:iam::aws:policy/PowerUserAccess",
                      { "Ref": "AWS::NoValue" }
                    ]
                  },
                  {
                    "Fn::If": [
                      "UseReadOnlyAccess",
                      "arn:aws:iam::aws:policy/ReadOnlyAccess",
                      { "Ref": "AWS::NoValue" }
                    ]
                  }
                ],
                "Tags": [
                  {
                    "Key": "Purpose",
                    "Value": "CrossAccountConsoleAccess"
                  },
                  {
                    "Key": "ManagedBy",
                    "Value": "CloudFormation"
                  }
                ]
              }
            }
          },
          "Outputs": {
            "RoleArn": {
              "Description": "ARN of the console access role",
              "Value": { "Fn::GetAtt": ["ConsoleAccessRole", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RoleArn" }
              }
            },
            "RoleName": {
              "Description": "Name of the console access role",
              "Value": { "Ref": "ConsoleAccessRole" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RoleName" }
              }
            },
            "ConsoleLink": {
              "Description": "Direct link to switch to this role in the AWS Console",
              "Value": {
                "Fn::Sub": "https://signin.aws.amazon.com/switchrole?roleName=${RoleName}&account=${AWS::AccountId}&displayName=${AWS::StackName}"
              }
            },
            "AccountId": {
              "Description": "Account ID where this role is deployed",
              "Value": { "Ref": "AWS::AccountId" }
            }
          }
        }
        """
}
