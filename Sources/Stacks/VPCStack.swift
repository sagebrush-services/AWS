import Foundation

/// CloudFormation stack for creating a VPC with public and private subnets
struct VPCStack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "VPC with public and private subnets across two availability zones",
          "Parameters": {
            "ClassB": {
              "Description": "Class B of VPC (10.XXX.0.0/16)",
              "Type": "Number",
              "Default": 10,
              "ConstraintDescription": "Must be in the range [0-255]",
              "MinValue": 0,
              "MaxValue": 255
            }
          },
          "Resources": {
            "VPC": {
              "Type": "AWS::EC2::VPC",
              "Properties": {
                "CidrBlock": { "Fn::Sub": "10.${ClassB}.0.0/16" },
                "EnableDnsSupport": true,
                "EnableDnsHostnames": true,
                "Tags": [
                  { "Key": "Name", "Value": { "Fn::Sub": "${AWS::StackName}-vpc" } }
                ]
              }
            },
            "InternetGateway": {
              "Type": "AWS::EC2::InternetGateway",
              "Properties": {
                "Tags": [
                  { "Key": "Name", "Value": { "Fn::Sub": "${AWS::StackName}-igw" } }
                ]
              }
            },
            "VPCGatewayAttachment": {
              "Type": "AWS::EC2::VPCGatewayAttachment",
              "Properties": {
                "VpcId": { "Ref": "VPC" },
                "InternetGatewayId": { "Ref": "InternetGateway" }
              }
            },
            "SubnetPublicA": {
              "Type": "AWS::EC2::Subnet",
              "Properties": {
                "AvailabilityZone": { "Fn::Select": [0, { "Fn::GetAZs": "" }] },
                "CidrBlock": { "Fn::Sub": "10.${ClassB}.0.0/24" },
                "MapPublicIpOnLaunch": true,
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  { "Key": "Name", "Value": { "Fn::Sub": "${AWS::StackName}-public-a" } }
                ]
              }
            },
            "SubnetPublicB": {
              "Type": "AWS::EC2::Subnet",
              "Properties": {
                "AvailabilityZone": { "Fn::Select": [1, { "Fn::GetAZs": "" }] },
                "CidrBlock": { "Fn::Sub": "10.${ClassB}.1.0/24" },
                "MapPublicIpOnLaunch": true,
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  { "Key": "Name", "Value": { "Fn::Sub": "${AWS::StackName}-public-b" } }
                ]
              }
            },
            "SubnetPrivateA": {
              "Type": "AWS::EC2::Subnet",
              "Properties": {
                "AvailabilityZone": { "Fn::Select": [0, { "Fn::GetAZs": "" }] },
                "CidrBlock": { "Fn::Sub": "10.${ClassB}.10.0/24" },
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  { "Key": "Name", "Value": { "Fn::Sub": "${AWS::StackName}-private-a" } }
                ]
              }
            },
            "SubnetPrivateB": {
              "Type": "AWS::EC2::Subnet",
              "Properties": {
                "AvailabilityZone": { "Fn::Select": [1, { "Fn::GetAZs": "" }] },
                "CidrBlock": { "Fn::Sub": "10.${ClassB}.11.0/24" },
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  { "Key": "Name", "Value": { "Fn::Sub": "${AWS::StackName}-private-b" } }
                ]
              }
            },
            "RouteTablePublic": {
              "Type": "AWS::EC2::RouteTable",
              "Properties": {
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  { "Key": "Name", "Value": { "Fn::Sub": "${AWS::StackName}-public-rt" } }
                ]
              }
            },
            "RouteTablePublicInternetRoute": {
              "Type": "AWS::EC2::Route",
              "DependsOn": "VPCGatewayAttachment",
              "Properties": {
                "RouteTableId": { "Ref": "RouteTablePublic" },
                "DestinationCidrBlock": "0.0.0.0/0",
                "GatewayId": { "Ref": "InternetGateway" }
              }
            },
            "RouteTableAssociationPublicA": {
              "Type": "AWS::EC2::SubnetRouteTableAssociation",
              "Properties": {
                "SubnetId": { "Ref": "SubnetPublicA" },
                "RouteTableId": { "Ref": "RouteTablePublic" }
              }
            },
            "RouteTableAssociationPublicB": {
              "Type": "AWS::EC2::SubnetRouteTableAssociation",
              "Properties": {
                "SubnetId": { "Ref": "SubnetPublicB" },
                "RouteTableId": { "Ref": "RouteTablePublic" }
              }
            },
            "NATGatewayEIP": {
              "Type": "AWS::EC2::EIP",
              "DependsOn": "VPCGatewayAttachment",
              "Properties": {
                "Domain": "vpc",
                "Tags": [
                  { "Key": "Name", "Value": { "Fn::Sub": "${AWS::StackName}-nat-eip" } }
                ]
              }
            },
            "NATGateway": {
              "Type": "AWS::EC2::NatGateway",
              "Properties": {
                "AllocationId": { "Fn::GetAtt": ["NATGatewayEIP", "AllocationId"] },
                "SubnetId": { "Ref": "SubnetPublicA" },
                "Tags": [
                  { "Key": "Name", "Value": { "Fn::Sub": "${AWS::StackName}-nat" } }
                ]
              }
            },
            "RouteTablePrivate": {
              "Type": "AWS::EC2::RouteTable",
              "Properties": {
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  { "Key": "Name", "Value": { "Fn::Sub": "${AWS::StackName}-private-rt" } }
                ]
              }
            },
            "RouteTablePrivateNATRoute": {
              "Type": "AWS::EC2::Route",
              "Properties": {
                "RouteTableId": { "Ref": "RouteTablePrivate" },
                "DestinationCidrBlock": "0.0.0.0/0",
                "NatGatewayId": { "Ref": "NATGateway" }
              }
            },
            "RouteTableAssociationPrivateA": {
              "Type": "AWS::EC2::SubnetRouteTableAssociation",
              "Properties": {
                "SubnetId": { "Ref": "SubnetPrivateA" },
                "RouteTableId": { "Ref": "RouteTablePrivate" }
              }
            },
            "RouteTableAssociationPrivateB": {
              "Type": "AWS::EC2::SubnetRouteTableAssociation",
              "Properties": {
                "SubnetId": { "Ref": "SubnetPrivateB" },
                "RouteTableId": { "Ref": "RouteTablePrivate" }
              }
            }
          },
          "Outputs": {
            "VPC": {
              "Description": "VPC ID",
              "Value": { "Ref": "VPC" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-VPC" }
              }
            },
            "SubnetsPublic": {
              "Description": "Public subnet IDs",
              "Value": { "Fn::Join": [",", [{ "Ref": "SubnetPublicA" }, { "Ref": "SubnetPublicB" }]] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-SubnetsPublic" }
              }
            },
            "SubnetsPrivate": {
              "Description": "Private subnet IDs",
              "Value": { "Fn::Join": [",", [{ "Ref": "SubnetPrivateA" }, { "Ref": "SubnetPrivateB" }]] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-SubnetsPrivate" }
              }
            },
            "CidrBlock": {
              "Description": "The CIDR block for the VPC",
              "Value": { "Fn::GetAtt": ["VPC", "CidrBlock"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-CidrBlock" }
              }
            }
          }
        }
        """
}
