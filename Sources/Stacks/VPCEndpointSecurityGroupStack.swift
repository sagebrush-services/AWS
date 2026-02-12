import Foundation

/// CloudFormation stack for creating a security group for VPC endpoints
/// Allows HTTPS traffic from within the VPC
struct VPCEndpointSecurityGroupStack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "Security group for VPC endpoints - allows HTTPS from VPC CIDR",
          "Parameters": {
            "VpcId": {
              "Description": "VPC ID where security group will be created",
              "Type": "AWS::EC2::VPC::Id"
            },
            "VpcCidr": {
              "Description": "CIDR block of the VPC",
              "Type": "String",
              "Default": "10.0.0.0/16"
            }
          },
          "Resources": {
            "VPCEndpointSecurityGroup": {
              "Type": "AWS::EC2::SecurityGroup",
              "Properties": {
                "GroupName": "vpc-endpoint-sg",
                "GroupDescription": "Security group for VPC endpoints - allows HTTPS from VPC",
                "VpcId": { "Ref": "VpcId" },
                "SecurityGroupIngress": [
                  {
                    "IpProtocol": "tcp",
                    "FromPort": 443,
                    "ToPort": 443,
                    "CidrIp": { "Ref": "VpcCidr" },
                    "Description": "Allow HTTPS from VPC CIDR for AWS service endpoints"
                  }
                ],
                "SecurityGroupEgress": [
                  {
                    "IpProtocol": "-1",
                    "CidrIp": "0.0.0.0/0",
                    "Description": "Allow all outbound traffic"
                  }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "vpc-endpoint-sg"
                  }
                ]
              }
            }
          },
          "Outputs": {
            "SecurityGroupId": {
              "Description": "Security group ID for VPC endpoints",
              "Value": { "Ref": "VPCEndpointSecurityGroup" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-SecurityGroupId" }
              }
            }
          }
        }
        """
}
