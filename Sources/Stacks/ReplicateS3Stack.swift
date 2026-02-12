import Foundation

/// CloudFormation stack for creating an S3 replication destination bucket
/// This stack creates a destination bucket in us-east-2 that receives replicated objects
/// from a source bucket, with delete marker replication disabled
struct ReplicateS3Stack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "S3 replication destination bucket with IAM role for replication (no delete marker replication)",
          "Parameters": {
            "SourceBucketStackName": {
              "Description": "Name of the CloudFormation stack containing the source S3 bucket",
              "Type": "String"
            }
          },
          "Resources": {
            "ReplicationRole": {
              "Type": "AWS::IAM::Role",
              "Properties": {
                "AssumeRolePolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [{
                    "Effect": "Allow",
                    "Principal": {
                      "Service": "s3.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                  }]
                },
                "Policies": [{
                  "PolicyName": "S3ReplicationPolicy",
                  "PolicyDocument": {
                    "Version": "2012-10-17",
                    "Statement": [
                      {
                        "Effect": "Allow",
                        "Action": [
                          "s3:GetReplicationConfiguration",
                          "s3:ListBucket"
                        ],
                        "Resource": {
                          "Fn::ImportValue": {
                            "Fn::Sub": "${SourceBucketStackName}-BucketArn"
                          }
                        }
                      },
                      {
                        "Effect": "Allow",
                        "Action": [
                          "s3:GetObjectVersionForReplication",
                          "s3:GetObjectVersionAcl",
                          "s3:GetObjectVersionTagging"
                        ],
                        "Resource": {
                          "Fn::Sub": [
                            "${BucketArn}/*",
                            {
                              "BucketArn": {
                                "Fn::ImportValue": {
                                  "Fn::Sub": "${SourceBucketStackName}-BucketArn"
                                }
                              }
                            }
                          ]
                        }
                      },
                      {
                        "Effect": "Allow",
                        "Action": [
                          "s3:ReplicateObject",
                          "s3:ReplicateTags"
                        ],
                        "Resource": {
                          "Fn::Sub": "${DestinationBucket.Arn}/*"
                        }
                      }
                    ]
                  }
                }]
              }
            },
            "DestinationBucket": {
              "Type": "AWS::S3::Bucket",
              "Properties": {
                "BucketName": {
                  "Fn::Sub": [
                    "${SourceBucketName}-replicate",
                    {
                      "SourceBucketName": {
                        "Fn::ImportValue": {
                          "Fn::Sub": "${SourceBucketStackName}-BucketName"
                        }
                      }
                    }
                  ]
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
                    }
                  }]
                },
                "VersioningConfiguration": {
                  "Status": "Enabled"
                },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": {
                      "Fn::Sub": [
                        "${SourceBucketName}-replicate",
                        {
                          "SourceBucketName": {
                            "Fn::ImportValue": {
                              "Fn::Sub": "${SourceBucketStackName}-BucketName"
                            }
                          }
                        }
                      ]
                    }
                  },
                  {
                    "Key": "ReplicationSource",
                    "Value": {
                      "Fn::ImportValue": {
                        "Fn::Sub": "${SourceBucketStackName}-BucketName"
                      }
                    }
                  }
                ]
              }
            }
          },
          "Outputs": {
            "DestinationBucketName": {
              "Description": "Name of the replication destination S3 bucket",
              "Value": { "Ref": "DestinationBucket" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DestinationBucketName" }
              }
            },
            "DestinationBucketArn": {
              "Description": "ARN of the replication destination S3 bucket",
              "Value": { "Fn::GetAtt": ["DestinationBucket", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DestinationBucketArn" }
              }
            },
            "ReplicationRoleArn": {
              "Description": "ARN of the IAM role for S3 replication",
              "Value": { "Fn::GetAtt": ["ReplicationRole", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-ReplicationRoleArn" }
              }
            }
          }
        }
        """
}
