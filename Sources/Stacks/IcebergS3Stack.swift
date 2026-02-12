import Foundation

/// CloudFormation stack for creating an S3 bucket optimized for long-term log storage with Glacier transitions
/// Reference: https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-transition-general-considerations.html
struct IcebergS3Stack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "S3 bucket for long-term log storage with Glacier lifecycle transitions",
          "Parameters": {
            "BucketName": {
              "Description": "Name of the Iceberg S3 bucket for log archiving (must be globally unique)",
              "Type": "String",
              "MinLength": 3,
              "MaxLength": 63,
              "AllowedPattern": "[a-z0-9.-]*",
              "ConstraintDescription": "Must contain only lowercase letters, numbers, hyphens, and periods"
            },
            "TransitionToGlacierDays": {
              "Description": "Number of days before transitioning to Glacier Flexible Retrieval",
              "Type": "Number",
              "Default": 90,
              "MinValue": 30,
              "ConstraintDescription": "Must be at least 30 days per AWS requirements"
            },
            "TransitionToDeepArchiveDays": {
              "Description": "Number of days before transitioning to Glacier Deep Archive",
              "Type": "Number",
              "Default": 365,
              "MinValue": 180,
              "ConstraintDescription": "Must be at least 180 days per AWS requirements"
            }
          },
          "Resources": {
            "IcebergBucket": {
              "Type": "AWS::S3::Bucket",
              "Properties": {
                "BucketName": { "Ref": "BucketName" },
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
                  "Status": "Enabled"
                },
                "LifecycleConfiguration": {
                  "Rules": [
                    {
                      "Id": "TransitionToGlacier",
                      "Status": "Enabled",
                      "Transitions": [
                        {
                          "TransitionInDays": { "Ref": "TransitionToGlacierDays" },
                          "StorageClass": "GLACIER"
                        },
                        {
                          "TransitionInDays": { "Ref": "TransitionToDeepArchiveDays" },
                          "StorageClass": "DEEP_ARCHIVE"
                        }
                      ]
                    },
                    {
                      "Id": "DeleteOldVersions",
                      "Status": "Enabled",
                      "NoncurrentVersionTransitions": [
                        {
                          "TransitionInDays": 30,
                          "StorageClass": "GLACIER"
                        },
                        {
                          "TransitionInDays": 90,
                          "StorageClass": "DEEP_ARCHIVE"
                        }
                      ],
                      "NoncurrentVersionExpirationInDays": 730
                    }
                  ]
                },
                "ObjectLockEnabled": false,
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Ref": "BucketName" }
                  },
                  {
                    "Key": "Purpose",
                    "Value": "LongTermLogArchival"
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
            "BucketName": {
              "Description": "Name of the Iceberg S3 bucket",
              "Value": { "Ref": "IcebergBucket" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-BucketName" }
              }
            },
            "BucketArn": {
              "Description": "ARN of the Iceberg S3 bucket",
              "Value": { "Fn::GetAtt": ["IcebergBucket", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-BucketArn" }
              }
            },
            "BucketDomainName": {
              "Description": "Domain name of the Iceberg S3 bucket",
              "Value": { "Fn::GetAtt": ["IcebergBucket", "DomainName"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-BucketDomainName" }
              }
            }
          }
        }
        """
}
