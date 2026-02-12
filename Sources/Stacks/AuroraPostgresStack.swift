import Foundation

/// CloudFormation stack for Aurora Serverless v2 PostgreSQL with Secrets Manager and cross-account access
struct AuroraPostgresStack: Stack {
    let housekeepingAccountId: String

    init(housekeepingAccountId: String = "374073887345") {
        self.housekeepingAccountId = housekeepingAccountId
    }

    var templateBody: String {
        """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "Aurora Serverless v2 PostgreSQL with Secrets Manager and cross-account access",
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
            "MinCapacity": {
              "Description": "Minimum Aurora Serverless v2 capacity units (0 - 128). Set to 0 for auto-pause capability.",
              "Type": "Number",
              "Default": 0,
              "MinValue": 0,
              "MaxValue": 128
            },
            "MaxCapacity": {
              "Description": "Maximum Aurora Serverless v2 capacity units (0.5 - 128)",
              "Type": "Number",
              "Default": 1,
              "MinValue": 0.5,
              "MaxValue": 128
            },
            "SecondsUntilAutoPause": {
              "Description": "Time in seconds before auto-pause after inactivity (300-86400). Only applies when MinCapacity is 0.",
              "Type": "Number",
              "Default": 300,
              "MinValue": 300,
              "MaxValue": 86400
            },
            "HousekeepingAccountId": {
              "Description": "AWS Account ID for housekeeping account (for cross-account secret access)",
              "Type": "String",
              "Default": "\(housekeepingAccountId)"
            }
          },
          "Resources": {
            "DBSecret": {
              "Type": "AWS::SecretsManager::Secret",
              "Properties": {
                "Description": "Aurora PostgreSQL master credentials",
                "GenerateSecretString": {
                  "SecretStringTemplate": "{\\"username\\": \\"postgres\\"}",
                  "GenerateStringKey": "password",
                  "PasswordLength": 32,
                  "ExcludeCharacters": "\\"@/\\\\ '",
                  "RequireEachIncludedType": true
                },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Fn::Sub": "${AWS::StackName}-secret" }
                  }
                ]
              }
            },
            "DBSecretResourcePolicy": {
              "Type": "AWS::SecretsManager::ResourcePolicy",
              "Properties": {
                "SecretId": { "Ref": "DBSecret" },
                "ResourcePolicy": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Principal": {
                        "AWS": {
                          "Fn::Sub": "arn:aws:iam::${HousekeepingAccountId}:root"
                        }
                      },
                      "Action": [
                        "secretsmanager:GetSecretValue",
                        "secretsmanager:DescribeSecret"
                      ],
                      "Resource": "*"
                    }
                  ]
                }
              }
            },
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
                "MasterUsername": {
                  "Fn::Sub": "{{resolve:secretsmanager:${DBSecret}::username}}"
                },
                "MasterUserPassword": {
                  "Fn::Sub": "{{resolve:secretsmanager:${DBSecret}::password}}"
                },
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
                  "MaxCapacity": { "Ref": "MaxCapacity" },
                  "SecondsUntilAutoPause": { "Ref": "SecondsUntilAutoPause" }
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
            },
            "DBSecretAttachment": {
              "Type": "AWS::SecretsManager::SecretTargetAttachment",
              "Properties": {
                "SecretId": { "Ref": "DBSecret" },
                "TargetId": { "Ref": "DBCluster" },
                "TargetType": "AWS::RDS::DBCluster"
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
            "SecretArn": {
              "Description": "ARN of the Secrets Manager secret containing database credentials and connection info",
              "Value": { "Ref": "DBSecret" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-SecretArn" }
              }
            },
            "SecurityGroupId": {
              "Description": "Security group ID for database access",
              "Value": { "Ref": "DBSecurityGroup" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-SecurityGroupId" }
              }
            }
          }
        }
        """
    }
}
