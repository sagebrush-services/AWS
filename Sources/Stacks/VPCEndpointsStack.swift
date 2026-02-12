import Foundation

/// CloudFormation stack for creating VPC Endpoints to replace NAT Gateways
/// Provides access to AWS services from Lambda functions in private subnets
/// without requiring expensive NAT Gateways ($32-45/month each)
struct VPCEndpointsStack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "VPC Endpoints for AWS services (S3, Secrets Manager, CloudWatch Logs) - replaces NAT Gateway",
          "Parameters": {
            "VpcId": {
              "Description": "VPC ID where endpoints will be created",
              "Type": "AWS::EC2::VPC::Id"
            },
            "PrivateSubnetIds": {
              "Description": "Comma-separated list of private subnet IDs",
              "Type": "List<AWS::EC2::Subnet::Id>"
            },
            "SecurityGroupId": {
              "Description": "Security group ID for interface endpoints (allows HTTPS from VPC)",
              "Type": "AWS::EC2::SecurityGroup::Id"
            }
          },
          "Resources": {
            "S3GatewayEndpoint": {
              "Type": "AWS::EC2::VPCEndpoint",
              "Properties": {
                "VpcId": { "Ref": "VpcId" },
                "ServiceName": { "Fn::Sub": "com.amazonaws.${AWS::Region}.s3" },
                "VpcEndpointType": "Gateway",
                "RouteTableIds": { "Ref": "AWS::NoValue" }
              }
            },
            "SecretsManagerInterfaceEndpoint": {
              "Type": "AWS::EC2::VPCEndpoint",
              "Properties": {
                "VpcId": { "Ref": "VpcId" },
                "ServiceName": { "Fn::Sub": "com.amazonaws.${AWS::Region}.secretsmanager" },
                "VpcEndpointType": "Interface",
                "PrivateDnsEnabled": true,
                "SubnetIds": { "Ref": "PrivateSubnetIds" },
                "SecurityGroupIds": [{ "Ref": "SecurityGroupId" }]
              }
            },
            "CloudWatchLogsInterfaceEndpoint": {
              "Type": "AWS::EC2::VPCEndpoint",
              "Properties": {
                "VpcId": { "Ref": "VpcId" },
                "ServiceName": { "Fn::Sub": "com.amazonaws.${AWS::Region}.logs" },
                "VpcEndpointType": "Interface",
                "PrivateDnsEnabled": true,
                "SubnetIds": { "Ref": "PrivateSubnetIds" },
                "SecurityGroupIds": [{ "Ref": "SecurityGroupId" }]
              }
            },
            "ECRAPIInterfaceEndpoint": {
              "Type": "AWS::EC2::VPCEndpoint",
              "Properties": {
                "VpcId": { "Ref": "VpcId" },
                "ServiceName": { "Fn::Sub": "com.amazonaws.${AWS::Region}.ecr.api" },
                "VpcEndpointType": "Interface",
                "PrivateDnsEnabled": true,
                "SubnetIds": { "Ref": "PrivateSubnetIds" },
                "SecurityGroupIds": [{ "Ref": "SecurityGroupId" }]
              }
            },
            "ECRDKRInterfaceEndpoint": {
              "Type": "AWS::EC2::VPCEndpoint",
              "Properties": {
                "VpcId": { "Ref": "VpcId" },
                "ServiceName": { "Fn::Sub": "com.amazonaws.${AWS::Region}.ecr.dkr" },
                "VpcEndpointType": "Interface",
                "PrivateDnsEnabled": true,
                "SubnetIds": { "Ref": "PrivateSubnetIds" },
                "SecurityGroupIds": [{ "Ref": "SecurityGroupId" }]
              }
            }
          },
          "Outputs": {
            "S3EndpointId": {
              "Description": "S3 Gateway Endpoint ID",
              "Value": { "Ref": "S3GatewayEndpoint" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-S3EndpointId" }
              }
            },
            "SecretsManagerEndpointId": {
              "Description": "Secrets Manager Interface Endpoint ID",
              "Value": { "Ref": "SecretsManagerInterfaceEndpoint" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-SecretsManagerEndpointId" }
              }
            },
            "CloudWatchLogsEndpointId": {
              "Description": "CloudWatch Logs Interface Endpoint ID",
              "Value": { "Ref": "CloudWatchLogsInterfaceEndpoint" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-CloudWatchLogsEndpointId" }
              }
            },
            "ECRAPIEndpointId": {
              "Description": "ECR API Interface Endpoint ID",
              "Value": { "Ref": "ECRAPIInterfaceEndpoint" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-ECRAPIEndpointId" }
              }
            },
            "ECRDKREndpointId": {
              "Description": "ECR DKR Interface Endpoint ID",
              "Value": { "Ref": "ECRDKRInterfaceEndpoint" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-ECRDKREndpointId" }
              }
            }
          }
        }
        """
}
