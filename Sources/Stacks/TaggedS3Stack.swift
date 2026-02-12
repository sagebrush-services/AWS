import Foundation

/// CloudFormation stack for creating S3 buckets with UID-based names and comprehensive tagging
/// Bucket names: sagebrush-<account-id>-<uuid>
/// Tags: Name (logical name), Purpose (detailed description), Environment, CostCenter, ManagedBy
struct TaggedS3Stack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "S3 bucket with UID-based name and comprehensive tagging for logical reference",
          "Parameters": {
            "UniqueId": {
              "Description": "Unique identifier (UUID) for the bucket name",
              "Type": "String",
              "MinLength": 8,
              "MaxLength": 64,
              "AllowedPattern": "[a-z0-9-]*",
              "ConstraintDescription": "Must contain only lowercase letters, numbers, and hyphens"
            },
            "LogicalName": {
              "Description": "Logical name for the bucket (used in Name tag for reference)",
              "Type": "String",
              "MinLength": 1,
              "MaxLength": 128,
              "AllowedValues": [
                "lambda-artifacts",
                "user-uploads",
                "application-logs",
                "mailroom",
                "email",
                "lambda-code",
                "billing-reports",
                "archive"
              ]
            },
            "Purpose": {
              "Description": "Detailed description of the bucket's purpose",
              "Type": "String",
              "MinLength": 1,
              "MaxLength": 256
            },
            "Environment": {
              "Description": "Environment for the bucket",
              "Type": "String",
              "AllowedValues": [
                "management",
                "production",
                "staging",
                "housekeeping",
                "neonlaw"
              ]
            },
            "CostCenter": {
              "Description": "Cost center for billing tracking",
              "Type": "String",
              "AllowedValues": [
                "Management",
                "Production",
                "Staging",
                "Housekeeping",
                "NeonLaw"
              ]
            },
            "EnableVersioning": {
              "Description": "Enable versioning on the bucket",
              "Type": "String",
              "Default": "false",
              "AllowedValues": ["true", "false"]
            }
          },
          "Conditions": {
            "ShouldEnableVersioning": {
              "Fn::Equals": [{ "Ref": "EnableVersioning" }, "true"]
            }
          },
          "Resources": {
            "S3Bucket": {
              "Type": "AWS::S3::Bucket",
              "Properties": {
                "BucketName": {
                  "Fn::Sub": "sagebrush-${AWS::AccountId}-${UniqueId}"
                },
                "PublicAccessBlockConfiguration": {
                  "BlockPublicAcls": true,
                  "BlockPublicPolicy": true,
                  "IgnorePublicAcls": true,
                  "RestrictPublicBuckets": true
                },
                "BucketEncryption": {
                  "ServerSideEncryptionConfiguration": [{
                    "ServerSideEncryptionByDefault": {
                      "SSEAlgorithm": "AES256"
                    },
                    "BucketKeyEnabled": true
                  }]
                },
                "VersioningConfiguration": {
                  "Fn::If": [
                    "ShouldEnableVersioning",
                    { "Status": "Enabled" },
                    { "Ref": "AWS::NoValue" }
                  ]
                },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Ref": "LogicalName" }
                  },
                  {
                    "Key": "Purpose",
                    "Value": { "Ref": "Purpose" }
                  },
                  {
                    "Key": "Environment",
                    "Value": { "Ref": "Environment" }
                  },
                  {
                    "Key": "CostCenter",
                    "Value": { "Ref": "CostCenter" }
                  },
                  {
                    "Key": "ManagedBy",
                    "Value": "Sagebrush-AWS-CLI"
                  }
                ]
              }
            }
          },
          "Outputs": {
            "BucketName": {
              "Description": "Physical name of the S3 bucket (sagebrush-<account-id>-<uuid>)",
              "Value": { "Ref": "S3Bucket" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-BucketName" }
              }
            },
            "BucketArn": {
              "Description": "ARN of the S3 bucket",
              "Value": { "Fn::GetAtt": ["S3Bucket", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-BucketArn" }
              }
            },
            "LogicalName": {
              "Description": "Logical name of the bucket (from Name tag)",
              "Value": { "Ref": "LogicalName" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-LogicalName" }
              }
            }
          }
        }
        """
}
