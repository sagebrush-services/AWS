import Foundation

/// CloudFormation stack for creating IAM group and policies in management account for cross-account console access
struct ConsoleAccessGroupStack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "IAM group and policies for cross-account console access from management account",
          "Parameters": {
            "GroupName": {
              "Type": "String",
              "Description": "Name of the IAM group for users who can switch roles",
              "Default": "CrossAccountAdministrators",
              "AllowedPattern": "^[\\\\w+=,.@-]+$",
              "ConstraintDescription": "Must be a valid IAM group name"
            },
            "ProductionAccountId": {
              "Type": "String",
              "Description": "Production AWS Account ID",
              "Default": "978489150794",
              "AllowedPattern": "^[0-9]{12}$"
            },
            "StagingAccountId": {
              "Type": "String",
              "Description": "Staging AWS Account ID",
              "Default": "889786867297",
              "AllowedPattern": "^[0-9]{12}$"
            },
            "HousekeepingAccountId": {
              "Type": "String",
              "Description": "Housekeeping AWS Account ID",
              "Default": "374073887345",
              "AllowedPattern": "^[0-9]{12}$"
            },
            "NeonLawAccountId": {
              "Type": "String",
              "Description": "NeonLaw AWS Account ID",
              "Default": "102186460229",
              "AllowedPattern": "^[0-9]{12}$"
            },
            "TargetRoleName": {
              "Type": "String",
              "Description": "Name of the role to assume in target accounts",
              "Default": "ConsoleAdminAccess",
              "AllowedPattern": "^[\\\\w+=,.@-]+$"
            }
          },
          "Resources": {
            "CrossAccountGroup": {
              "Type": "AWS::IAM::Group",
              "Properties": {
                "GroupName": { "Ref": "GroupName" },
                "ManagedPolicyArns": [
                  "arn:aws:iam::aws:policy/IAMUserChangePassword",
                  "arn:aws:iam::aws:policy/IAMUserSSHKeys"
                ]
              }
            },
            "AssumeRolePolicy": {
              "Type": "AWS::IAM::ManagedPolicy",
              "Properties": {
                "ManagedPolicyName": {
                  "Fn::Sub": "${GroupName}-AssumeRolePolicy"
                },
                "Description": "Allows assuming roles in target accounts for console access",
                "Groups": [
                  { "Ref": "CrossAccountGroup" }
                ],
                "PolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Sid": "AssumeRoleInTargetAccounts",
                      "Effect": "Allow",
                      "Action": "sts:AssumeRole",
                      "Resource": [
                        { "Fn::Sub": "arn:aws:iam::${ProductionAccountId}:role/${TargetRoleName}" },
                        { "Fn::Sub": "arn:aws:iam::${StagingAccountId}:role/${TargetRoleName}" },
                        { "Fn::Sub": "arn:aws:iam::${HousekeepingAccountId}:role/${TargetRoleName}" },
                        { "Fn::Sub": "arn:aws:iam::${NeonLawAccountId}:role/${TargetRoleName}" }
                      ]
                    },
                    {
                      "Sid": "ViewAccountInfo",
                      "Effect": "Allow",
                      "Action": [
                        "iam:GetAccountSummary",
                        "iam:ListAccountAliases"
                      ],
                      "Resource": "*"
                    }
                  ]
                }
              }
            }
          },
          "Outputs": {
            "GroupName": {
              "Description": "Name of the IAM group for cross-account console access",
              "Value": { "Ref": "CrossAccountGroup" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-GroupName" }
              }
            },
            "GroupArn": {
              "Description": "ARN of the IAM group",
              "Value": { "Fn::GetAtt": ["CrossAccountGroup", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-GroupArn" }
              }
            },
            "PolicyArn": {
              "Description": "ARN of the assume role policy",
              "Value": { "Ref": "AssumeRolePolicy" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-PolicyArn" }
              }
            },
            "ProductionRoleSwitchLink": {
              "Description": "Link to switch to production account",
              "Value": {
                "Fn::Sub": "https://signin.aws.amazon.com/switchrole?roleName=${TargetRoleName}&account=${ProductionAccountId}&displayName=Production"
              }
            },
            "StagingRoleSwitchLink": {
              "Description": "Link to switch to staging account",
              "Value": {
                "Fn::Sub": "https://signin.aws.amazon.com/switchrole?roleName=${TargetRoleName}&account=${StagingAccountId}&displayName=Staging"
              }
            },
            "HousekeepingRoleSwitchLink": {
              "Description": "Link to switch to housekeeping account",
              "Value": {
                "Fn::Sub": "https://signin.aws.amazon.com/switchrole?roleName=${TargetRoleName}&account=${HousekeepingAccountId}&displayName=Housekeeping"
              }
            },
            "NeonLawRoleSwitchLink": {
              "Description": "Link to switch to NeonLaw account",
              "Value": {
                "Fn::Sub": "https://signin.aws.amazon.com/switchrole?roleName=${TargetRoleName}&account=${NeonLawAccountId}&displayName=NeonLaw"
              }
            }
          }
        }
        """
}
