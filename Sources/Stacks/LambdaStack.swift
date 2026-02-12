import Foundation

struct LambdaStack: Stack {
    let functionName: String
    let s3StackName: String
    let s3Key: String
    let scheduleExpression: String
    let timeout: Int
    let memorySize: Int
    let additionalPolicies: [String]

    init(
        functionName: String = "FiveMinuteFunction",
        s3StackName: String,
        s3Key: String = "lambdas/five_minutes/bootstrap.zip",
        scheduleExpression: String = "rate(5 minutes)",
        timeout: Int = 30,
        memorySize: Int = 128,
        additionalPolicies: [String] = []
    ) {
        self.functionName = functionName
        self.s3StackName = s3StackName
        self.s3Key = s3Key
        self.scheduleExpression = scheduleExpression
        self.timeout = timeout
        self.memorySize = memorySize
        self.additionalPolicies = additionalPolicies
    }

    private var additionalPoliciesJSON: String {
        var policies: [String] = [
            """
                    {
                      "PolicyName": "LambdaS3Access",
                      "PolicyDocument": {
                        "Version": "2012-10-17",
                        "Statement": [
                          {
                            "Effect": "Allow",
                            "Action": [
                              "s3:GetObject"
                            ],
                            "Resource": {
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
                          }
                        ]
                      }
                    }
            """
        ]

        for policyJSON in additionalPolicies {
            policies.append(policyJSON)
        }

        return policies.joined(separator: ",\n")
    }

    var templateBody: String {
        """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "Lambda function with EventBridge cron trigger (every 5 minutes)",
          "Parameters": {
            "FunctionName": {
              "Type": "String",
              "Default": "\(functionName)",
              "Description": "Name of the Lambda function"
            },
            "S3StackName": {
              "Type": "String",
              "Default": "\(s3StackName)",
              "Description": "Name of the S3 stack containing Lambda code"
            },
            "S3Key": {
              "Type": "String",
              "Default": "\(s3Key)",
              "Description": "S3 key path to the Lambda deployment package"
            }
          },
          "Resources": {
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
                  "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
                ],
                "Policies": [
                  \(additionalPoliciesJSON)
                ]
              }
            },
            "LambdaFunction": {
              "Type": "AWS::Lambda::Function",
              "Properties": {
                "FunctionName": {
                  "Ref": "FunctionName"
                },
                "Runtime": "provided.al2",
                "Handler": "bootstrap",
                "Role": {
                  "Fn::GetAtt": [
                    "LambdaExecutionRole",
                    "Arn"
                  ]
                },
                "Code": {
                  "S3Bucket": {
                    "Fn::ImportValue": {
                      "Fn::Sub": "${S3StackName}-BucketName"
                    }
                  },
                  "S3Key": {
                    "Ref": "S3Key"
                  }
                },
                "Timeout": \(timeout),
                "MemorySize": \(memorySize),
                "Architectures": [
                  "arm64"
                ],
                "Description": "Lambda function triggered every 5 minutes by EventBridge"
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
            },
            "EventBridgeRule": {
              "Type": "AWS::Events::Rule",
              "Properties": {
                "Name": {
                  "Fn::Sub": "${FunctionName}-FiveMinuteCron"
                },
                "Description": "Trigger Lambda function on schedule",
                "ScheduleExpression": "\(scheduleExpression)",
                "State": "ENABLED",
                "Targets": [
                  {
                    "Arn": {
                      "Fn::GetAtt": [
                        "LambdaFunction",
                        "Arn"
                      ]
                    },
                    "Id": "LambdaTarget"
                  }
                ]
              }
            },
            "LambdaInvokePermission": {
              "Type": "AWS::Lambda::Permission",
              "Properties": {
                "FunctionName": {
                  "Ref": "LambdaFunction"
                },
                "Action": "lambda:InvokeFunction",
                "Principal": "events.amazonaws.com",
                "SourceArn": {
                  "Fn::GetAtt": [
                    "EventBridgeRule",
                    "Arn"
                  ]
                }
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
                "Fn::GetAtt": [
                  "LambdaFunction",
                  "Arn"
                ]
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-FunctionArn"
                }
              }
            },
            "EventBridgeRuleName": {
              "Description": "Name of the EventBridge rule",
              "Value": {
                "Ref": "EventBridgeRule"
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-EventBridgeRuleName"
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
