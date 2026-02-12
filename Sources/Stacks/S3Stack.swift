import Foundation

/// CloudFormation stack for creating an S3 bucket
struct S3Stack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "S3 bucket with versioning and encryption",
          "Parameters": {
            "BucketName": {
              "Description": "Name of the S3 bucket (must be globally unique)",
              "Type": "String",
              "MinLength": 3,
              "MaxLength": 63,
              "AllowedPattern": "[a-z0-9.-]*",
              "ConstraintDescription": "Must contain only lowercase letters, numbers, hyphens, and periods"
            },
            "PublicAccess": {
              "Description": "Allow public access to the bucket",
              "Type": "String",
              "Default": "false",
              "AllowedValues": ["true", "false"]
            },
            "ReplicationEnabled": {
              "Description": "Enable S3 replication to destination bucket",
              "Type": "String",
              "Default": "false",
              "AllowedValues": ["true", "false"]
            },
            "ReplicateStackName": {
              "Description": "Name of the CloudFormation stack containing the replication destination (required if ReplicationEnabled is true)",
              "Type": "String",
              "Default": ""
            }
          },
          "Conditions": {
            "IsPublic": { "Fn::Equals": [{ "Ref": "PublicAccess" }, "true"] },
            "HasReplication": { "Fn::Equals": [{ "Ref": "ReplicationEnabled" }, "true"] }
          },
          "Resources": {
            "S3Bucket": {
              "Type": "AWS::S3::Bucket",
              "Properties": {
                "BucketName": { "Ref": "BucketName" },
                "PublicAccessBlockConfiguration": {
                  "BlockPublicAcls": { "Fn::If": ["IsPublic", false, true] },
                  "BlockPublicPolicy": { "Fn::If": ["IsPublic", false, true] },
                  "IgnorePublicAcls": { "Fn::If": ["IsPublic", false, true] },
                  "RestrictPublicBuckets": { "Fn::If": ["IsPublic", false, true] }
                },
                "BucketEncryption": {
                  "ServerSideEncryptionConfiguration": [{
                    "ServerSideEncryptionByDefault": {
                      "SSEAlgorithm": "AES256"
                    }
                  }]
                },
                "VersioningConfiguration": {
                  "Status": "Enabled"
                },
                "ReplicationConfiguration": {
                  "Fn::If": [
                    "HasReplication",
                    {
                      "Role": {
                        "Fn::ImportValue": {
                          "Fn::Sub": "${ReplicateStackName}-ReplicationRoleArn"
                        }
                      },
                      "Rules": [{
                        "Id": "ReplicateAll",
                        "Status": "Enabled",
                        "Priority": 1,
                        "Filter": {},
                        "Destination": {
                          "Bucket": {
                            "Fn::ImportValue": {
                              "Fn::Sub": "${ReplicateStackName}-DestinationBucketArn"
                            }
                          },
                          "ReplicationTime": {
                            "Status": "Enabled",
                            "Time": {
                              "Minutes": 15
                            }
                          },
                          "Metrics": {
                            "Status": "Enabled",
                            "EventThreshold": {
                              "Minutes": 15
                            }
                          }
                        },
                        "DeleteMarkerReplication": {
                          "Status": "Disabled"
                        }
                      }]
                    },
                    { "Ref": "AWS::NoValue" }
                  ]
                },
                "LifecycleConfiguration": {
                  "Rules": [{
                    "Id": "DeleteOldVersions",
                    "NoncurrentVersionExpirationInDays": 90,
                    "Status": "Enabled"
                  }]
                },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Ref": "BucketName" }
                  }
                ]
              }
            }
          },
          "Outputs": {
            "BucketName": {
              "Description": "Name of the S3 bucket",
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
            "BucketDomainName": {
              "Description": "Domain name of the S3 bucket",
              "Value": { "Fn::GetAtt": ["S3Bucket", "DomainName"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-BucketDomainName" }
              }
            }
          }
        }
        """
}
