import Foundation

/// CloudFormation stack for Migration Lambda function with VPC and Aurora access
struct MigrationLambdaStack: Stack {
    var templateBody: String {
        """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "Lambda function for running database migrations and seeds in VPC with Aurora access",
          "Parameters": {
            "FunctionName": {
              "Type": "String",
              "Description": "Name of the Lambda function",
              "Default": "MigrationRunner",
              "MinLength": 1,
              "MaxLength": 64
            },
            "VPCStackName": {
              "Type": "String",
              "Description": "Name of the VPC stack to reference",
              "Default": "oregon-vpc"
            },
            "AuroraStackName": {
              "Type": "String",
              "Description": "Name of the Aurora PostgreSQL stack to reference"
            },
            "S3BucketName": {
              "Type": "String",
              "Description": "S3 bucket name containing Lambda deployment package",
              "MinLength": 3,
              "MaxLength": 63
            },
            "S3Key": {
              "Type": "String",
              "Description": "S3 key path to the Lambda deployment package",
              "Default": "lambda/migration-runner/bootstrap.zip"
            }
          },
          "Resources": {
            "LambdaSecurityGroup": {
              "Type": "AWS::EC2::SecurityGroup",
              "Properties": {
                "GroupDescription": "Security group for Migration Lambda function",
                "VpcId": {
                  "Fn::ImportValue": {
                    "Fn::Sub": "${VPCStackName}-VPC"
                  }
                },
                "SecurityGroupEgress": [
                  {
                    "IpProtocol": "tcp",
                    "FromPort": 5432,
                    "ToPort": 5432,
                    "DestinationSecurityGroupId": {
                      "Fn::ImportValue": {
                        "Fn::Sub": "${AuroraStackName}-SecurityGroupId"
                      }
                    },
                    "Description": "PostgreSQL access to Aurora"
                  },
                  {
                    "IpProtocol": "tcp",
                    "FromPort": 443,
                    "ToPort": 443,
                    "CidrIp": "0.0.0.0/0",
                    "Description": "HTTPS for AWS API calls (Secrets Manager)"
                  }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": {
                      "Fn::Sub": "${FunctionName}-sg"
                    }
                  }
                ]
              }
            },
            "LambdaExecutionRole": {
              "Type": "AWS::IAM::Role",
              "Properties": {
                "RoleName": {
                  "Fn::Sub": "${FunctionName}-ExecutionRole"
                },
                "AssumeRolePolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Principal": {
                        "Service": "lambda.amazonaws.com"
                      },
                      "Action": "sts:AssumeRole"
                    }
                  ]
                },
                "ManagedPolicyArns": [
                  "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
                ],
                "Policies": [
                  {
                    "PolicyName": "SecretsManagerReadPolicy",
                    "PolicyDocument": {
                      "Version": "2012-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Action": [
                            "secretsmanager:GetSecretValue",
                            "secretsmanager:DescribeSecret"
                          ],
                          "Resource": {
                            "Fn::ImportValue": {
                              "Fn::Sub": "${AuroraStackName}-SecretArn"
                            }
                          }
                        }
                      ]
                    }
                  }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": {
                      "Fn::Sub": "${FunctionName}-ExecutionRole"
                    }
                  }
                ]
              }
            },
            "LambdaFunction": {
              "Type": "AWS::Lambda::Function",
              "Properties": {
                "FunctionName": {
                  "Ref": "FunctionName"
                },
                "Description": "Runs Fluent migrations and seeds for PostgreSQL database",
                "Runtime": "provided.al2023",
                "Handler": "bootstrap",
                "Role": {
                  "Fn::GetAtt": ["LambdaExecutionRole", "Arn"]
                },
                "Code": {
                  "S3Bucket": {
                    "Ref": "S3BucketName"
                  },
                  "S3Key": {
                    "Ref": "S3Key"
                  }
                },
                "Timeout": 300,
                "MemorySize": 512,
                "Architectures": [
                  "arm64"
                ],
                "Environment": {
                  "Variables": {
                    "DATABASE_HOST": {
                      "Fn::ImportValue": {
                        "Fn::Sub": "${AuroraStackName}-ClusterEndpoint"
                      }
                    },
                    "DATABASE_PORT": {
                      "Fn::ImportValue": {
                        "Fn::Sub": "${AuroraStackName}-Port"
                      }
                    },
                    "DATABASE_NAME": {
                      "Fn::ImportValue": {
                        "Fn::Sub": "${AuroraStackName}-DatabaseName"
                      }
                    },
                    "DATABASE_SECRET_ARN": {
                      "Fn::ImportValue": {
                        "Fn::Sub": "${AuroraStackName}-SecretArn"
                      }
                    }
                  }
                },
                "VpcConfig": {
                  "SubnetIds": {
                    "Fn::Split": [
                      ",",
                      {
                        "Fn::ImportValue": {
                          "Fn::Sub": "${VPCStackName}-SubnetsPrivate"
                        }
                      }
                    ]
                  },
                  "SecurityGroupIds": [
                    {
                      "Ref": "LambdaSecurityGroup"
                    }
                  ]
                },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": {
                      "Ref": "FunctionName"
                    }
                  }
                ]
              }
            },
            "LambdaLogGroup": {
              "Type": "AWS::Logs::LogGroup",
              "Properties": {
                "LogGroupName": {
                  "Fn::Sub": "/aws/lambda/${FunctionName}"
                },
                "RetentionInDays": 7
              }
            }
          },
          "Outputs": {
            "FunctionName": {
              "Description": "Name of the Lambda function",
              "Value": {
                "Ref": "LambdaFunction"
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-FunctionName"
                }
              }
            },
            "FunctionArn": {
              "Description": "ARN of the Lambda function",
              "Value": {
                "Fn::GetAtt": ["LambdaFunction", "Arn"]
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-FunctionArn"
                }
              }
            },
            "ExecutionRoleArn": {
              "Description": "ARN of the Lambda execution role",
              "Value": {
                "Fn::GetAtt": ["LambdaExecutionRole", "Arn"]
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-ExecutionRoleArn"
                }
              }
            },
            "SecurityGroupId": {
              "Description": "Security group ID for Lambda function",
              "Value": {
                "Ref": "LambdaSecurityGroup"
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-SecurityGroupId"
                }
              }
            },
            "LogGroupName": {
              "Description": "CloudWatch log group for Lambda function",
              "Value": {
                "Ref": "LambdaLogGroup"
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-LogGroupName"
                }
              }
            }
          }
        }
        """
    }
}
