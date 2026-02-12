import Foundation

/// CloudFormation stack for Application Load Balancer with Route53 DNS
struct ALBStack: Stack {
    let domainName: String

    init(domainName: String = "www.sagebrush.services") {
        self.domainName = domainName
    }

    var templateBody: String {
        """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "Application Load Balancer with Route53 DNS for ECS services",
          "Parameters": {
            "VPCStackName": {
              "Description": "Name of the VPC stack to reference",
              "Type": "String"
            },
            "ECSStackName": {
              "Description": "Name of the ECS stack to reference",
              "Type": "String"
            },
            "DomainName": {
              "Description": "Domain name for the application",
              "Type": "String",
              "Default": "\(domainName)"
            }
          },
          "Resources": {
            "ALBSecurityGroup": {
              "Type": "AWS::EC2::SecurityGroup",
              "Properties": {
                "GroupDescription": "Security group for Application Load Balancer",
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
                    "Description": "HTTP from anywhere"
                  },
                  {
                    "IpProtocol": "tcp",
                    "FromPort": 443,
                    "ToPort": 443,
                    "CidrIp": "0.0.0.0/0",
                    "Description": "HTTPS from anywhere"
                  }
                ],
                "Tags": [
                  { "Key": "Name", "Value": { "Fn::Sub": "${AWS::StackName}-alb-sg" } }
                ]
              }
            },
            "LoadBalancer": {
              "Type": "AWS::ElasticLoadBalancingV2::LoadBalancer",
              "Properties": {
                "Name": { "Fn::Sub": "${AWS::StackName}-alb" },
                "Type": "application",
                "Scheme": "internet-facing",
                "IpAddressType": "ipv4",
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
                  { "Ref": "ALBSecurityGroup" }
                ],
                "Tags": [
                  { "Key": "Name", "Value": { "Fn::Sub": "${AWS::StackName}-alb" } }
                ]
              }
            },
            "TargetGroup": {
              "Type": "AWS::ElasticLoadBalancingV2::TargetGroup",
              "Properties": {
                "Name": { "Fn::Sub": "${AWS::StackName}-tg" },
                "Port": 80,
                "Protocol": "HTTP",
                "TargetType": "ip",
                "VpcId": {
                  "Fn::ImportValue": {
                    "Fn::Sub": "${VPCStackName}-VPC"
                  }
                },
                "HealthCheckEnabled": true,
                "HealthCheckPath": "/",
                "HealthCheckProtocol": "HTTP",
                "HealthCheckIntervalSeconds": 30,
                "HealthCheckTimeoutSeconds": 5,
                "HealthyThresholdCount": 2,
                "UnhealthyThresholdCount": 2,
                "Matcher": {
                  "HttpCode": "200-299"
                },
                "Tags": [
                  { "Key": "Name", "Value": { "Fn::Sub": "${AWS::StackName}-tg" } }
                ]
              }
            },
            "Listener": {
              "Type": "AWS::ElasticLoadBalancingV2::Listener",
              "Properties": {
                "LoadBalancerArn": { "Ref": "LoadBalancer" },
                "Port": 80,
                "Protocol": "HTTP",
                "DefaultActions": [
                  {
                    "Type": "forward",
                    "TargetGroupArn": { "Ref": "TargetGroup" }
                  }
                ]
              }
            }
          },
          "Outputs": {
            "LoadBalancerArn": {
              "Description": "ARN of the Application Load Balancer",
              "Value": { "Ref": "LoadBalancer" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-LoadBalancerArn" }
              }
            },
            "LoadBalancerDNS": {
              "Description": "DNS name of the Application Load Balancer",
              "Value": { "Fn::GetAtt": ["LoadBalancer", "DNSName"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-LoadBalancerDNS" }
              }
            },
            "TargetGroupArn": {
              "Description": "ARN of the Target Group",
              "Value": { "Ref": "TargetGroup" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-TargetGroupArn" }
              }
            },
            "LoadBalancerDNSForRoute53": {
              "Description": "DNS name of ALB for Route53 CNAME record",
              "Value": { "Fn::GetAtt": ["LoadBalancer", "DNSName"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DNSName" }
              }
            }
          }
        }
        """
    }
}
