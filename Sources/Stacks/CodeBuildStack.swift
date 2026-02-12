import Foundation

/// CloudFormation stack for CodeBuild project to build Swift Lambda on ARM64
struct CodeBuildStack: Stack {
    var templateBody: String {
        """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "CodeBuild project for building Swift Lambda functions on Amazon Linux 2023 ARM64",
          "Parameters": {
            "ProjectName": {
              "Type": "String",
              "Description": "Name of the CodeBuild project",
              "MinLength": 1,
              "MaxLength": 255
            },
            "CodeCommitRepositoryName": {
              "Type": "String",
              "Description": "Name of the CodeCommit repository to build from",
              "MinLength": 1,
              "MaxLength": 100
            },
            "S3BucketName": {
              "Type": "String",
              "Description": "S3 bucket name for storing Lambda deployment artifacts",
              "MinLength": 3,
              "MaxLength": 63
            },
            "LambdaFunctionName": {
              "Type": "String",
              "Description": "Name of the Lambda function to update after build",
              "MinLength": 1,
              "MaxLength": 64
            }
          },
          "Resources": {
            "CodeBuildServiceRole": {
              "Type": "AWS::IAM::Role",
              "Properties": {
                "RoleName": {
                  "Fn::Sub": "${ProjectName}-CodeBuildRole"
                },
                "AssumeRolePolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Principal": {
                        "Service": "codebuild.amazonaws.com"
                      },
                      "Action": "sts:AssumeRole"
                    }
                  ]
                },
                "Policies": [
                  {
                    "PolicyName": "CodeBuildBasePolicy",
                    "PolicyDocument": {
                      "Version": "2012-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Action": [
                            "logs:CreateLogGroup",
                            "logs:CreateLogStream",
                            "logs:PutLogEvents"
                          ],
                          "Resource": [
                            {
                              "Fn::Sub": "arn:aws:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/codebuild/${ProjectName}"
                            },
                            {
                              "Fn::Sub": "arn:aws:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/codebuild/${ProjectName}:*"
                            }
                          ]
                        }
                      ]
                    }
                  },
                  {
                    "PolicyName": "CodeCommitReadPolicy",
                    "PolicyDocument": {
                      "Version": "2012-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Action": [
                            "codecommit:GitPull"
                          ],
                          "Resource": {
                            "Fn::Sub": "arn:aws:codecommit:${AWS::Region}:${AWS::AccountId}:${CodeCommitRepositoryName}"
                          }
                        }
                      ]
                    }
                  },
                  {
                    "PolicyName": "S3ArtifactPolicy",
                    "PolicyDocument": {
                      "Version": "2012-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Action": [
                            "s3:PutObject",
                            "s3:PutObjectAcl"
                          ],
                          "Resource": {
                            "Fn::Sub": "arn:aws:s3:::${S3BucketName}/*"
                          }
                        }
                      ]
                    }
                  },
                  {
                    "PolicyName": "LambdaUpdatePolicy",
                    "PolicyDocument": {
                      "Version": "2012-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Action": [
                            "lambda:UpdateFunctionCode",
                            "lambda:GetFunction"
                          ],
                          "Resource": {
                            "Fn::Sub": "arn:aws:lambda:${AWS::Region}:${AWS::AccountId}:function:${LambdaFunctionName}"
                          }
                        }
                      ]
                    }
                  },
                  {
                    "PolicyName": "LambdaInvokePolicy",
                    "PolicyDocument": {
                      "Version": "2012-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Action": [
                            "lambda:InvokeFunction"
                          ],
                          "Resource": {
                            "Fn::Sub": "arn:aws:lambda:${AWS::Region}:${AWS::AccountId}:function:${LambdaFunctionName}"
                          }
                        }
                      ]
                    }
                  }
                ]
              }
            },
            "CodeBuildProject": {
              "Type": "AWS::CodeBuild::Project",
              "Properties": {
                "Name": {
                  "Ref": "ProjectName"
                },
                "Description": "Build Swift Lambda function on Amazon Linux 2023 ARM64",
                "ServiceRole": {
                  "Fn::GetAtt": ["CodeBuildServiceRole", "Arn"]
                },
                "Artifacts": {
                  "Type": "NO_ARTIFACTS"
                },
                "Environment": {
                  "Type": "ARM_CONTAINER",
                  "ComputeType": "BUILD_GENERAL1_SMALL",
                  "Image": "aws/codebuild/amazonlinux2-aarch64-standard:3.0",
                  "PrivilegedMode": true,
                  "EnvironmentVariables": [
                    {
                      "Name": "S3_BUCKET",
                      "Value": {
                        "Ref": "S3BucketName"
                      },
                      "Type": "PLAINTEXT"
                    },
                    {
                      "Name": "LAMBDA_FUNCTION_NAME",
                      "Value": {
                        "Ref": "LambdaFunctionName"
                      },
                      "Type": "PLAINTEXT"
                    },
                    {
                      "Name": "AWS_REGION",
                      "Value": {
                        "Ref": "AWS::Region"
                      },
                      "Type": "PLAINTEXT"
                    }
                  ]
                },
                "Source": {
                  "Type": "CODECOMMIT",
                  "Location": {
                    "Fn::Sub": "https://git-codecommit.${AWS::Region}.amazonaws.com/v1/repos/${CodeCommitRepositoryName}"
                  }
                },
                "TimeoutInMinutes": 60,
                "LogsConfig": {
                  "CloudWatchLogs": {
                    "Status": "ENABLED",
                    "GroupName": {
                      "Fn::Sub": "/aws/codebuild/${ProjectName}"
                    }
                  }
                },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": {
                      "Ref": "ProjectName"
                    }
                  }
                ]
              }
            },
            "CodeCommitEventRole": {
              "Type": "AWS::IAM::Role",
              "Properties": {
                "AssumeRolePolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Principal": {
                        "Service": "events.amazonaws.com"
                      },
                      "Action": "sts:AssumeRole"
                    }
                  ]
                },
                "Policies": [
                  {
                    "PolicyName": "StartCodeBuildPolicy",
                    "PolicyDocument": {
                      "Version": "2012-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Action": "codebuild:StartBuild",
                          "Resource": {
                            "Fn::GetAtt": ["CodeBuildProject", "Arn"]
                          }
                        }
                      ]
                    }
                  }
                ]
              }
            },
            "CodeCommitEventRule": {
              "Type": "AWS::Events::Rule",
              "Properties": {
                "Description": "Trigger CodeBuild on CodeCommit push",
                "EventPattern": {
                  "source": ["aws.codecommit"],
                  "detail-type": ["CodeCommit Repository State Change"],
                  "detail": {
                    "repositoryName": [
                      {
                        "Ref": "CodeCommitRepositoryName"
                      }
                    ],
                    "event": ["referenceCreated", "referenceUpdated"]
                  }
                },
                "State": "ENABLED",
                "Targets": [
                  {
                    "Arn": {
                      "Fn::GetAtt": ["CodeBuildProject", "Arn"]
                    },
                    "RoleArn": {
                      "Fn::GetAtt": ["CodeCommitEventRole", "Arn"]
                    },
                    "Id": "CodeBuildTarget"
                  }
                ]
              }
            }
          },
          "Outputs": {
            "ProjectName": {
              "Description": "CodeBuild project name",
              "Value": {
                "Ref": "CodeBuildProject"
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-ProjectName"
                }
              }
            },
            "ProjectArn": {
              "Description": "CodeBuild project ARN",
              "Value": {
                "Fn::GetAtt": ["CodeBuildProject", "Arn"]
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-ProjectArn"
                }
              }
            },
            "ServiceRoleArn": {
              "Description": "CodeBuild service role ARN",
              "Value": {
                "Fn::GetAtt": ["CodeBuildServiceRole", "Arn"]
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-ServiceRoleArn"
                }
              }
            }
          }
        }
        """
    }
}
