import Foundation

/// CloudFormation stack for creating an Aurora Serverless v2 PostgreSQL database
struct RDSStack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "Aurora Serverless v2 PostgreSQL database in VPC with private subnets",
          "Parameters": {
            "VPCStackName": {
              "Description": "Name of the VPC stack to reference",
              "Type": "String"
            },
            "DBName": {
              "Description": "Database name",
              "Type": "String",
              "Default": "app",
              "MinLength": 1,
              "MaxLength": 64,
              "AllowedPattern": "[a-zA-Z][a-zA-Z0-9]*",
              "ConstraintDescription": "Must begin with a letter and contain only alphanumeric characters"
            },
            "DBUsername": {
              "Description": "Master username for the Aurora cluster",
              "Type": "String",
              "Default": "postgres",
              "MinLength": 1,
              "MaxLength": 16,
              "AllowedPattern": "[a-zA-Z][a-zA-Z0-9]*",
              "ConstraintDescription": "Must begin with a letter and contain only alphanumeric characters"
            },
            "DBPassword": {
              "Description": "Master password for the Aurora cluster",
              "Type": "String",
              "NoEcho": true,
              "MinLength": 8,
              "MaxLength": 41,
              "AllowedPattern": "[a-zA-Z0-9]*",
              "ConstraintDescription": "Must contain only alphanumeric characters and be between 8-41 characters"
            },
            "MinCapacity": {
              "Description": "Minimum Aurora Serverless v2 capacity units (0.5 - 128)",
              "Type": "Number",
              "Default": 0.5,
              "MinValue": 0.5,
              "MaxValue": 128
            },
            "MaxCapacity": {
              "Description": "Maximum Aurora Serverless v2 capacity units (0.5 - 128)",
              "Type": "Number",
              "Default": 1,
              "MinValue": 0.5,
              "MaxValue": 128
            }
          },
          "Resources": {
            "DBSubnetGroup": {
              "Type": "AWS::RDS::DBSubnetGroup",
              "Properties": {
                "DBSubnetGroupDescription": "Subnet group for Aurora Serverless database",
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
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Fn::Sub": "${AWS::StackName}-subnet-group" }
                  }
                ]
              }
            },
            "DBSecurityGroup": {
              "Type": "AWS::EC2::SecurityGroup",
              "Properties": {
                "GroupDescription": "Security group for Aurora PostgreSQL database",
                "VpcId": {
                  "Fn::ImportValue": {
                    "Fn::Sub": "${VPCStackName}-VPC"
                  }
                },
                "SecurityGroupIngress": [
                  {
                    "IpProtocol": "tcp",
                    "FromPort": 5432,
                    "ToPort": 5432,
                    "CidrIp": {
                      "Fn::ImportValue": {
                        "Fn::Sub": "${VPCStackName}-CidrBlock"
                      }
                    },
                    "Description": "PostgreSQL access from VPC"
                  }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Fn::Sub": "${AWS::StackName}-sg" }
                  }
                ]
              }
            },
            "DBCluster": {
              "Type": "AWS::RDS::DBCluster",
              "DeletionPolicy": "Snapshot",
              "Properties": {
                "DBClusterIdentifier": {
                  "Fn::Sub": "${AWS::StackName}-cluster"
                },
                "DatabaseName": { "Ref": "DBName" },
                "Engine": "aurora-postgresql",
                "EngineMode": "provisioned",
                "EngineVersion": "16.4",
                "MasterUsername": { "Ref": "DBUsername" },
                "MasterUserPassword": { "Ref": "DBPassword" },
                "VpcSecurityGroupIds": [
                  { "Ref": "DBSecurityGroup" }
                ],
                "DBSubnetGroupName": { "Ref": "DBSubnetGroup" },
                "BackupRetentionPeriod": 7,
                "PreferredBackupWindow": "03:00-04:00",
                "PreferredMaintenanceWindow": "sun:04:00-sun:05:00",
                "StorageEncrypted": true,
                "EnableCloudwatchLogsExports": ["postgresql"],
                "DeletionProtection": false,
                "ServerlessV2ScalingConfiguration": {
                  "MinCapacity": { "Ref": "MinCapacity" },
                  "MaxCapacity": { "Ref": "MaxCapacity" }
                },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Fn::Sub": "${AWS::StackName}-cluster" }
                  }
                ]
              }
            },
            "DBInstance": {
              "Type": "AWS::RDS::DBInstance",
              "Properties": {
                "DBInstanceIdentifier": {
                  "Fn::Sub": "${AWS::StackName}-instance"
                },
                "DBClusterIdentifier": { "Ref": "DBCluster" },
                "Engine": "aurora-postgresql",
                "DBInstanceClass": "db.serverless",
                "PubliclyAccessible": false,
                "EnablePerformanceInsights": true,
                "PerformanceInsightsRetentionPeriod": 7,
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Fn::Sub": "${AWS::StackName}-instance" }
                  }
                ]
              }
            }
          },
          "Outputs": {
            "ClusterEndpoint": {
              "Description": "Aurora cluster writer endpoint",
              "Value": {
                "Fn::GetAtt": ["DBCluster", "Endpoint.Address"]
              },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-ClusterEndpoint" }
              }
            },
            "ClusterReadEndpoint": {
              "Description": "Aurora cluster reader endpoint",
              "Value": {
                "Fn::GetAtt": ["DBCluster", "ReadEndpoint.Address"]
              },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-ClusterReadEndpoint" }
              }
            },
            "DatabasePort": {
              "Description": "Aurora PostgreSQL port",
              "Value": {
                "Fn::GetAtt": ["DBCluster", "Endpoint.Port"]
              },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-Port" }
              }
            },
            "DatabaseName": {
              "Description": "Database name",
              "Value": { "Ref": "DBName" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DatabaseName" }
              }
            },
            "DatabaseURL": {
              "Description": "Complete PostgreSQL database URL",
              "Value": {
                "Fn::Join": [
                  "",
                  [
                    "postgresql://",
                    { "Ref": "DBUsername" },
                    ":",
                    { "Ref": "DBPassword" },
                    "@",
                    { "Fn::GetAtt": ["DBCluster", "Endpoint.Address"] },
                    ":",
                    { "Fn::GetAtt": ["DBCluster", "Endpoint.Port"] },
                    "/",
                    { "Ref": "DBName" },
                    "?sslmode=require"
                  ]
                ]
              },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DatabaseURL" }
              }
            }
          }
        }
        """
}
