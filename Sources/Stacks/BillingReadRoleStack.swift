import Foundation

/// CloudFormation stack for creating billing read role in Management account
struct BillingReadRoleStack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "IAM role for reading Cost Explorer billing data across all organization accounts",
          "Parameters": {
            "HousekeepingAccountId": {
              "Type": "String",
              "Description": "AWS Account ID of the Housekeeping account that will assume this role",
              "Default": "374073887345",
              "AllowedPattern": "^[0-9]{12}$",
              "ConstraintDescription": "Must be a 12-digit AWS account ID"
            },
            "RoleName": {
              "Type": "String",
              "Description": "Name of the IAM role to create",
              "Default": "BillingReadRole",
              "AllowedPattern": "^[\\\\w+=,.@-]+$",
              "ConstraintDescription": "Must be a valid IAM role name"
            }
          },
          "Resources": {
            "BillingReadRole": {
              "Type": "AWS::IAM::Role",
              "Properties": {
                "RoleName": { "Ref": "RoleName" },
                "Description": "Allows Housekeeping account to read Cost Explorer billing data for daily reports",
                "AssumeRolePolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Principal": {
                        "AWS": { "Fn::Sub": "arn:aws:iam::${HousekeepingAccountId}:root" }
                      },
                      "Action": "sts:AssumeRole"
                    }
                  ]
                },
                "Tags": [
                  {
                    "Key": "Purpose",
                    "Value": "BillingReporting"
                  },
                  {
                    "Key": "ManagedBy",
                    "Value": "CloudFormation"
                  }
                ]
              }
            },
            "CostExplorerReadPolicy": {
              "Type": "AWS::IAM::Policy",
              "Properties": {
                "PolicyName": "CostExplorerReadAccess",
                "PolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Action": [
                        "ce:GetCostAndUsage",
                        "ce:GetCostForecast"
                      ],
                      "Resource": "*"
                    }
                  ]
                },
                "Roles": [
                  { "Ref": "BillingReadRole" }
                ]
              }
            }
          },
          "Outputs": {
            "RoleArn": {
              "Description": "ARN of the billing read role",
              "Value": { "Fn::GetAtt": ["BillingReadRole", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RoleArn" }
              }
            },
            "RoleName": {
              "Description": "Name of the billing read role",
              "Value": { "Ref": "BillingReadRole" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RoleName" }
              }
            },
            "HousekeepingAccountId": {
              "Description": "Account ID allowed to assume this role",
              "Value": { "Ref": "HousekeepingAccountId" }
            }
          }
        }
        """
}
