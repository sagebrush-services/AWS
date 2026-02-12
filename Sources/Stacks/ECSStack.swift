import Foundation

/// CloudFormation stack for creating an ECS Cluster with Fargate support
struct ECSStack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "ECS Cluster with Fargate support",
          "Parameters": {
            "VPCStackName": {
              "Description": "Name of the VPC stack to reference",
              "Type": "String"
            },
            "ClusterName": {
              "Description": "Name of the ECS cluster",
              "Type": "String",
              "Default": "app-cluster"
            },
            "TargetGroupArn": {
              "Description": "Optional Target Group ARN for load balancer integration",
              "Type": "String",
              "Default": ""
            }
          },
          "Conditions": {
            "HasTargetGroup": {
              "Fn::Not": [
                {
                  "Fn::Equals": [
                    { "Ref": "TargetGroupArn" },
                    ""
                  ]
                }
              ]
            }
          },
          "Resources": {
            "ECSCluster": {
              "Type": "AWS::ECS::Cluster",
              "Properties": {
                "ClusterName": { "Ref": "ClusterName" },
                "CapacityProviders": ["FARGATE", "FARGATE_SPOT"],
                "DefaultCapacityProviderStrategy": [
                  {
                    "CapacityProvider": "FARGATE",
                    "Weight": 1
                  }
                ],
                "ClusterSettings": [
                  {
                    "Name": "containerInsights",
                    "Value": "enabled"
                  }
                ],
                "Tags": [
                  { "Key": "Name", "Value": { "Ref": "ClusterName" } }
                ]
              }
            },
            "ECSTaskExecutionRole": {
              "Type": "AWS::IAM::Role",
              "Properties": {
                "AssumeRolePolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Principal": {
                        "Service": "ecs-tasks.amazonaws.com"
                      },
                      "Action": "sts:AssumeRole"
                    }
                  ]
                },
                "ManagedPolicyArns": [
                  "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
                ],
                "Tags": [
                  { "Key": "Name", "Value": { "Fn::Sub": "${AWS::StackName}-execution-role" } }
                ]
              }
            },
            "ECSTaskRole": {
              "Type": "AWS::IAM::Role",
              "Properties": {
                "AssumeRolePolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Principal": {
                        "Service": "ecs-tasks.amazonaws.com"
                      },
                      "Action": "sts:AssumeRole"
                    }
                  ]
                },
                "Policies": [
                  {
                    "PolicyName": "ECSTaskPolicy",
                    "PolicyDocument": {
                      "Version": "2012-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Action": [
                            "s3:GetObject",
                            "s3:PutObject"
                          ],
                          "Resource": "*"
                        }
                      ]
                    }
                  }
                ],
                "Tags": [
                  { "Key": "Name", "Value": { "Fn::Sub": "${AWS::StackName}-task-role" } }
                ]
              }
            },
            "ECSSecurityGroup": {
              "Type": "AWS::EC2::SecurityGroup",
              "Properties": {
                "GroupDescription": "Security group for ECS tasks",
                "VpcId": {
                  "Fn::ImportValue": {
                    "Fn::Sub": "${VPCStackName}-VPC"
                  }
                },
                "SecurityGroupIngress": [
                  {
                    "IpProtocol": "tcp",
                    "FromPort": 80,
                    "ToPort": 80,
                    "CidrIp": "0.0.0.0/0",
                    "Description": "HTTP access"
                  },
                  {
                    "IpProtocol": "tcp",
                    "FromPort": 443,
                    "ToPort": 443,
                    "CidrIp": "0.0.0.0/0",
                    "Description": "HTTPS access"
                  },
                  {
                    "IpProtocol": "tcp",
                    "FromPort": 8080,
                    "ToPort": 8080,
                    "CidrIp": "0.0.0.0/0",
                    "Description": "Application port"
                  }
                ],
                "Tags": [
                  { "Key": "Name", "Value": { "Fn::Sub": "${AWS::StackName}-sg" } }
                ]
              }
            },
            "CloudWatchLogsGroup": {
              "Type": "AWS::Logs::LogGroup",
              "Properties": {
                "LogGroupName": { "Fn::Sub": "/ecs/${ClusterName}" },
                "RetentionInDays": 7
              }
            },
            "TaskDefinition": {
              "Type": "AWS::ECS::TaskDefinition",
              "Properties": {
                "Family": { "Fn::Sub": "${ClusterName}-minimal-task" },
                "NetworkMode": "awsvpc",
                "RequiresCompatibilities": ["FARGATE"],
                "Cpu": "256",
                "Memory": "512",
                "ExecutionRoleArn": { "Fn::GetAtt": ["ECSTaskExecutionRole", "Arn"] },
                "TaskRoleArn": { "Fn::GetAtt": ["ECSTaskRole", "Arn"] },
                "ContainerDefinitions": [
                  {
                    "Name": "nginx",
                    "Image": "public.ecr.aws/nginx/nginx:latest",
                    "Essential": true,
                    "PortMappings": [
                      {
                        "ContainerPort": 80,
                        "Protocol": "tcp"
                      }
                    ],
                    "LogConfiguration": {
                      "LogDriver": "awslogs",
                      "Options": {
                        "awslogs-group": { "Ref": "CloudWatchLogsGroup" },
                        "awslogs-region": { "Ref": "AWS::Region" },
                        "awslogs-stream-prefix": "nginx"
                      }
                    }
                  }
                ],
                "Tags": [
                  { "Key": "Name", "Value": { "Fn::Sub": "${ClusterName}-minimal-task" } }
                ]
              }
            },
            "Service": {
              "Type": "AWS::ECS::Service",
              "Properties": {
                "ServiceName": { "Fn::Sub": "${ClusterName}-minimal-service" },
                "Cluster": { "Ref": "ECSCluster" },
                "TaskDefinition": { "Ref": "TaskDefinition" },
                "DesiredCount": 1,
                "LaunchType": "FARGATE",
                "LoadBalancers": {
                  "Fn::If": [
                    "HasTargetGroup",
                    [
                      {
                        "TargetGroupArn": { "Ref": "TargetGroupArn" },
                        "ContainerName": "nginx",
                        "ContainerPort": 80
                      }
                    ],
                    { "Ref": "AWS::NoValue" }
                  ]
                },
                "NetworkConfiguration": {
                  "AwsvpcConfiguration": {
                    "AssignPublicIp": "ENABLED",
                    "Subnets": {
                      "Fn::Split": [
                        ",",
                        {
                          "Fn::ImportValue": {
                            "Fn::Sub": "${VPCStackName}-SubnetsPublic"
                          }
                        }
                      ]
                    },
                    "SecurityGroups": [
                      { "Ref": "ECSSecurityGroup" }
                    ]
                  }
                },
                "Tags": [
                  { "Key": "Name", "Value": { "Fn::Sub": "${ClusterName}-minimal-service" } }
                ]
              }
            }
          },
          "Outputs": {
            "ClusterName": {
              "Description": "ECS Cluster name",
              "Value": { "Ref": "ECSCluster" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-ClusterName" }
              }
            },
            "ClusterArn": {
              "Description": "ECS Cluster ARN",
              "Value": { "Fn::GetAtt": ["ECSCluster", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-ClusterArn" }
              }
            },
            "TaskExecutionRoleArn": {
              "Description": "ECS Task Execution Role ARN",
              "Value": { "Fn::GetAtt": ["ECSTaskExecutionRole", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-TaskExecutionRoleArn" }
              }
            },
            "TaskRoleArn": {
              "Description": "ECS Task Role ARN",
              "Value": { "Fn::GetAtt": ["ECSTaskRole", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-TaskRoleArn" }
              }
            },
            "SecurityGroupId": {
              "Description": "ECS Security Group ID",
              "Value": { "Ref": "ECSSecurityGroup" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-SecurityGroupId" }
              }
            },
            "LogGroupName": {
              "Description": "CloudWatch Logs Group Name",
              "Value": { "Ref": "CloudWatchLogsGroup" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-LogGroupName" }
              }
            },
            "TaskDefinitionArn": {
              "Description": "ECS Task Definition ARN",
              "Value": { "Ref": "TaskDefinition" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-TaskDefinitionArn" }
              }
            },
            "ServiceName": {
              "Description": "ECS Service Name",
              "Value": { "Fn::GetAtt": ["Service", "Name"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-ServiceName" }
              }
            }
          }
        }
        """
}
