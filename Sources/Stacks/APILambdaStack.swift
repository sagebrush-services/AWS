import Foundation

/// CloudFormation stack for API Lambda with API Gateway integration
struct APILambdaStack: Stack {
    let vpcStackName: String
    let auroraStackName: String
    let s3StackName: String

    var templateBody: String {
        """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "API Lambda with API Gateway, VPC, RDS, and S3 integration",
          "Parameters": {
            "VPCStackName": {
              "Description": "Name of the VPC stack",
              "Type": "String",
              "Default": "\(vpcStackName)"
            },
            "AuroraStackName": {
              "Description": "Name of the Aurora stack",
              "Type": "String",
              "Default": "\(auroraStackName)"
            },
            "S3StackName": {
              "Description": "Name of the S3 stack",
              "Type": "String",
              "Default": "\(s3StackName)"
            },
            "FunctionCodeBucket": {
              "Description": "S3 bucket containing Lambda deployment package",
              "Type": "String"
            },
            "FunctionCodeKey": {
              "Description": "S3 key for Lambda deployment package",
              "Type": "String",
              "Default": "api/bootstrap.zip"
            }
          },
          "Resources": {
            "LambdaSecurityGroup": {
              "Type": "AWS::EC2::SecurityGroup",
              "Properties": {
                "GroupDescription": "Security group for API Lambda function",
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
                    "Description": "PostgreSQL access"
                  },
                  {
                    "IpProtocol": "tcp",
                    "FromPort": 443,
                    "ToPort": 443,
                    "CidrIp": "0.0.0.0/0",
                    "Description": "HTTPS for AWS APIs"
                  }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Fn::Sub": "${AWS::StackName}-lambda-sg" }
                  }
                ]
              }
            },
            "LambdaExecutionRole": {
              "Type": "AWS::IAM::Role",
              "Properties": {
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
                    "PolicyName": "SecretsManagerAccess",
                    "PolicyDocument": {
                      "Version": "2012-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Action": [
                            "secretsmanager:GetSecretValue"
                          ],
                          "Resource": {
                            "Fn::ImportValue": {
                              "Fn::Sub": "${AuroraStackName}-SecretArn"
                            }
                          }
                        }
                      ]
                    }
                  },
                  {
                    "PolicyName": "S3Access",
                    "PolicyDocument": {
                      "Version": "2012-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Action": [
                            "s3:GetObject",
                            "s3:PutObject",
                            "s3:DeleteObject",
                            "s3:ListBucket"
                          ],
                          "Resource": [
                            {
                              "Fn::Sub": [
                                "arn:aws:s3:::${BucketName}",
                                {
                                  "BucketName": {
                                    "Fn::ImportValue": {
                                      "Fn::Sub": "${S3StackName}-BucketName"
                                    }
                                  }
                                }
                              ]
                            },
                            {
                              "Fn::Sub": [
                                "arn:aws:s3:::${BucketName}/*",
                                {
                                  "BucketName": {
                                    "Fn::ImportValue": {
                                      "Fn::Sub": "${S3StackName}-BucketName"
                                    }
                                  }
                                }
                              ]
                            }
                          ]
                        }
                      ]
                    }
                  }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Fn::Sub": "${AWS::StackName}-lambda-role" }
                  }
                ]
              }
            },
            "APIFunction": {
              "Type": "AWS::Lambda::Function",
              "Properties": {
                "FunctionName": { "Fn::Sub": "${AWS::StackName}-api" },
                "Runtime": "provided.al2023",
                "Architectures": ["arm64"],
                "Handler": "bootstrap",
                "Code": {
                  "S3Bucket": { "Ref": "FunctionCodeBucket" },
                  "S3Key": { "Ref": "FunctionCodeKey" }
                },
                "Role": { "Fn::GetAtt": ["LambdaExecutionRole", "Arn"] },
                "Timeout": 30,
                "MemorySize": 512,
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
                    { "Ref": "LambdaSecurityGroup" }
                  ]
                },
                "Environment": {
                  "Variables": {
                    "DB_SECRET_ARN": {
                      "Fn::ImportValue": {
                        "Fn::Sub": "${AuroraStackName}-SecretArn"
                      }
                    },
                    "S3_BUCKET_NAME": {
                      "Fn::ImportValue": {
                        "Fn::Sub": "${S3StackName}-BucketName"
                      }
                    }
                  }
                },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Fn::Sub": "${AWS::StackName}-api" }
                  }
                ]
              }
            },
            "APIGateway": {
              "Type": "AWS::ApiGatewayV2::Api",
              "Properties": {
                "Name": { "Fn::Sub": "${AWS::StackName}-api" },
                "ProtocolType": "HTTP",
                "Target": { "Fn::GetAtt": ["APIFunction", "Arn"] }
              }
            },
            "LambdaPermission": {
              "Type": "AWS::Lambda::Permission",
              "Properties": {
                "FunctionName": { "Ref": "APIFunction" },
                "Action": "lambda:InvokeFunction",
                "Principal": "apigateway.amazonaws.com",
                "SourceArn": {
                  "Fn::Sub": "arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${APIGateway}/*"
                }
              }
            },
            "LogGroup": {
              "Type": "AWS::Logs::LogGroup",
              "Properties": {
                "LogGroupName": {
                  "Fn::Sub": "/aws/lambda/${APIFunction}"
                },
                "RetentionInDays": 7
              }
            }
          },
          "Outputs": {
            "FunctionArn": {
              "Description": "ARN of the Lambda function",
              "Value": { "Fn::GetAtt": ["APIFunction", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-FunctionArn" }
              }
            },
            "APIEndpoint": {
              "Description": "API Gateway endpoint URL",
              "Value": {
                "Fn::Sub": "https://${APIGateway}.execute-api.${AWS::Region}.amazonaws.com"
              },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-APIEndpoint" }
              }
            }
          }
        }
        """
    }
}
