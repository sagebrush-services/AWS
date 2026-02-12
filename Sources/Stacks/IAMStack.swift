import Foundation

/// CloudFormation stack for creating the SagebrushCLIRole with least privilege permissions
struct IAMStack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "IAM role for Sagebrush CLI cross-account access with least privilege",
          "Parameters": {
            "ManagementAccountId": {
              "Description": "AWS Account ID of the management account",
              "Type": "String",
              "Default": "731099197338",
              "AllowedPattern": "[0-9]{12}",
              "ConstraintDescription": "Must be a valid 12-digit AWS account ID"
            }
          },
          "Resources": {
            "SagebrushCLIRole": {
              "Type": "AWS::IAM::Role",
              "Properties": {
                "RoleName": "SagebrushCLIRole",
                "Description": "Role for Sagebrush CLI to manage infrastructure via CloudFormation",
                "AssumeRolePolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Principal": {
                        "AWS": { "Fn::Sub": "arn:aws:iam::${ManagementAccountId}:root" }
                      },
                      "Action": "sts:AssumeRole",
                      "Condition": {
                        "StringEquals": {
                          "sts:ExternalId": "sagebrush-cli"
                        }
                      }
                    }
                  ]
                },
                "ManagedPolicyArns": [
                  { "Ref": "SagebrushCLIPolicyCore" },
                  { "Ref": "SagebrushCLIPolicyVPC" },
                  { "Ref": "SagebrushCLIPolicyIAM" }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "SagebrushCLIRole"
                  },
                  {
                    "Key": "ManagedBy",
                    "Value": "CloudFormation"
                  }
                ]
              }
            },
            "SagebrushCLIPolicyCore": {
              "Type": "AWS::IAM::ManagedPolicy",
              "Properties": {
                "ManagedPolicyName": "SagebrushCLIPolicyCore",
                "Description": "Core AWS service permissions for Sagebrush CLI",
                "PolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Sid": "CloudFormationAccess",
                      "Effect": "Allow",
                      "Action": [
                        "cloudformation:*"
                      ],
                      "Resource": "*"
                    },
                    {
                      "Sid": "CodeCommitAccess",
                      "Effect": "Allow",
                      "Action": [
                        "codecommit:*"
                      ],
                      "Resource": "*"
                    },
                    {
                      "Sid": "CodeBuildAccess",
                      "Effect": "Allow",
                      "Action": [
                        "codebuild:CreateProject",
                        "codebuild:DeleteProject",
                        "codebuild:UpdateProject",
                        "codebuild:BatchGetProjects",
                        "codebuild:ListProjects",
                        "codebuild:StartBuild",
                        "codebuild:StopBuild",
                        "codebuild:BatchGetBuilds",
                        "codebuild:ListBuildsForProject"
                      ],
                      "Resource": "*"
                    },
                    {
                      "Sid": "S3Access",
                      "Effect": "Allow",
                      "Action": [
                        "s3:CreateBucket",
                        "s3:DeleteBucket",
                        "s3:GetBucket*",
                        "s3:ListBucket*",
                        "s3:PutBucket*",
                        "s3:GetEncryptionConfiguration",
                        "s3:PutEncryptionConfiguration",
                        "s3:GetReplicationConfiguration",
                        "s3:PutReplicationConfiguration",
                        "s3:PutLifecycleConfiguration",
                        "s3:GetLifecycleConfiguration",
                        "s3:PutObject",
                        "s3:GetObject",
                        "s3:DeleteObject",
                        "s3:ListMultipartUploadParts",
                        "s3:AbortMultipartUpload"
                      ],
                      "Resource": "*"
                    },
                    {
                      "Sid": "RDSAccess",
                      "Effect": "Allow",
                      "Action": [
                        "rds:CreateDBCluster",
                        "rds:DeleteDBCluster",
                        "rds:DescribeDBClusters",
                        "rds:ModifyDBCluster",
                        "rds:CreateDBInstance",
                        "rds:DeleteDBInstance",
                        "rds:DescribeDBInstances",
                        "rds:ModifyDBInstance",
                        "rds:CreateDBSubnetGroup",
                        "rds:DeleteDBSubnetGroup",
                        "rds:DescribeDBSubnetGroups",
                        "rds:AddTagsToResource",
                        "rds:ListTagsForResource",
                        "rds:RemoveTagsFromResource",
                        "rds:CreateDBClusterSnapshot",
                        "rds:DeleteDBClusterSnapshot",
                        "rds:DescribeDBClusterSnapshots"
                      ],
                      "Resource": "*"
                    },
                    {
                      "Sid": "SecretsManagerAccess",
                      "Effect": "Allow",
                      "Action": [
                        "secretsmanager:CreateSecret",
                        "secretsmanager:DeleteSecret",
                        "secretsmanager:DescribeSecret",
                        "secretsmanager:GetSecretValue",
                        "secretsmanager:PutSecretValue",
                        "secretsmanager:UpdateSecret",
                        "secretsmanager:TagResource",
                        "secretsmanager:UntagResource",
                        "secretsmanager:PutResourcePolicy",
                        "secretsmanager:DeleteResourcePolicy",
                        "secretsmanager:GetResourcePolicy",
                        "secretsmanager:GetRandomPassword"
                      ],
                      "Resource": "*"
                    },
                    {
                      "Sid": "ECSAccess",
                      "Effect": "Allow",
                      "Action": [
                        "ecs:CreateCluster",
                        "ecs:DeleteCluster",
                        "ecs:DescribeClusters",
                        "ecs:UpdateCluster",
                        "ecs:RegisterTaskDefinition",
                        "ecs:DeregisterTaskDefinition",
                        "ecs:DescribeTaskDefinition",
                        "ecs:CreateService",
                        "ecs:DeleteService",
                        "ecs:DescribeServices",
                        "ecs:UpdateService",
                        "ecs:TagResource",
                        "ecs:UntagResource"
                      ],
                      "Resource": "*"
                    },
                    {
                      "Sid": "LambdaAccess",
                      "Effect": "Allow",
                      "Action": [
                        "lambda:CreateFunction",
                        "lambda:DeleteFunction",
                        "lambda:GetFunction",
                        "lambda:UpdateFunctionCode",
                        "lambda:UpdateFunctionConfiguration",
                        "lambda:AddPermission",
                        "lambda:RemovePermission",
                        "lambda:TagResource",
                        "lambda:UntagResource"
                      ],
                      "Resource": "*"
                    },
                    {
                      "Sid": "LoadBalancerAccess",
                      "Effect": "Allow",
                      "Action": [
                        "elasticloadbalancing:CreateLoadBalancer",
                        "elasticloadbalancing:DeleteLoadBalancer",
                        "elasticloadbalancing:DescribeLoadBalancers",
                        "elasticloadbalancing:ModifyLoadBalancerAttributes",
                        "elasticloadbalancing:CreateTargetGroup",
                        "elasticloadbalancing:DeleteTargetGroup",
                        "elasticloadbalancing:DescribeTargetGroups",
                        "elasticloadbalancing:ModifyTargetGroupAttributes",
                        "elasticloadbalancing:CreateListener",
                        "elasticloadbalancing:DeleteListener",
                        "elasticloadbalancing:DescribeListeners",
                        "elasticloadbalancing:AddTags",
                        "elasticloadbalancing:RemoveTags"
                      ],
                      "Resource": "*"
                    },
                    {
                      "Sid": "Route53Access",
                      "Effect": "Allow",
                      "Action": [
                        "route53:CreateHostedZone",
                        "route53:DeleteHostedZone",
                        "route53:GetHostedZone",
                        "route53:ListHostedZones",
                        "route53:ChangeResourceRecordSets",
                        "route53:ListResourceRecordSets",
                        "route53:GetChange"
                      ],
                      "Resource": "*"
                    },
                    {
                      "Sid": "ACMAccess",
                      "Effect": "Allow",
                      "Action": [
                        "acm:RequestCertificate",
                        "acm:DeleteCertificate",
                        "acm:DescribeCertificate",
                        "acm:ListCertificates",
                        "acm:AddTagsToCertificate",
                        "acm:RemoveTagsFromCertificate"
                      ],
                      "Resource": "*"
                    },
                    {
                      "Sid": "SESAccess",
                      "Effect": "Allow",
                      "Action": [
                        "ses:CreateEmailIdentity",
                        "ses:DeleteEmailIdentity",
                        "ses:GetEmailIdentity",
                        "ses:ListEmailIdentities",
                        "ses:PutEmailIdentityDkimSigningAttributes",
                        "ses:PutEmailIdentityDkimAttributes",
                        "ses:GetEmailIdentityDkimAttributes",
                        "ses:TagResource",
                        "ses:UntagResource"
                      ],
                      "Resource": "*"
                    },
                    {
                      "Sid": "EventBridgeAccess",
                      "Effect": "Allow",
                      "Action": [
                        "events:PutRule",
                        "events:DeleteRule",
                        "events:DescribeRule",
                        "events:PutTargets",
                        "events:RemoveTargets",
                        "events:TagResource",
                        "events:UntagResource"
                      ],
                      "Resource": "*"
                    },
                    {
                      "Sid": "LogsAccess",
                      "Effect": "Allow",
                      "Action": [
                        "logs:CreateLogGroup",
                        "logs:DeleteLogGroup",
                        "logs:DescribeLogGroups",
                        "logs:PutRetentionPolicy",
                        "logs:TagLogGroup",
                        "logs:UntagLogGroup"
                      ],
                      "Resource": "*"
                    },
                    {
                      "Sid": "SNSAccess",
                      "Effect": "Allow",
                      "Action": [
                        "sns:CreateTopic",
                        "sns:DeleteTopic",
                        "sns:GetTopicAttributes",
                        "sns:SetTopicAttributes",
                        "sns:Subscribe",
                        "sns:Unsubscribe",
                        "sns:ListTopics",
                        "sns:ListSubscriptionsByTopic",
                        "sns:TagResource",
                        "sns:UntagResource"
                      ],
                      "Resource": "*"
                    },
                    {
                      "Sid": "BudgetsAccess",
                      "Effect": "Allow",
                      "Action": [
                        "budgets:CreateBudget",
                        "budgets:DeleteBudget",
                        "budgets:DescribeBudget",
                        "budgets:ModifyBudget",
                        "budgets:ViewBudget"
                      ],
                      "Resource": "*"
                    },
                    {
                      "Sid": "OrganizationsAccess",
                      "Effect": "Allow",
                      "Action": [
                        "organizations:CreatePolicy",
                        "organizations:DeletePolicy",
                        "organizations:DescribePolicy",
                        "organizations:UpdatePolicy",
                        "organizations:AttachPolicy",
                        "organizations:DetachPolicy",
                        "organizations:ListPolicies",
                        "organizations:ListPoliciesForTarget",
                        "organizations:ListTargetsForPolicy",
                        "organizations:DescribeOrganization",
                        "organizations:ListRoots",
                        "organizations:ListAccounts",
                        "organizations:TagResource",
                        "organizations:UntagResource"
                      ],
                      "Resource": "*"
                    }
                  ]
                }
              }
            },
            "SagebrushCLIPolicyVPC": {
              "Type": "AWS::IAM::ManagedPolicy",
              "Properties": {
                "ManagedPolicyName": "SagebrushCLIPolicyVPC",
                "Description": "VPC and networking permissions for Sagebrush CLI",
                "PolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Sid": "VPCAccess",
                      "Effect": "Allow",
                      "Action": [
                        "ec2:CreateVpc",
                        "ec2:DeleteVpc",
                        "ec2:DescribeVpcs",
                        "ec2:ModifyVpcAttribute",
                        "ec2:CreateSubnet",
                        "ec2:DeleteSubnet",
                        "ec2:DescribeSubnets",
                        "ec2:ModifySubnetAttribute",
                        "ec2:CreateInternetGateway",
                        "ec2:DeleteInternetGateway",
                        "ec2:AttachInternetGateway",
                        "ec2:DetachInternetGateway",
                        "ec2:DescribeInternetGateways",
                        "ec2:CreateNatGateway",
                        "ec2:DeleteNatGateway",
                        "ec2:DescribeNatGateways",
                        "ec2:CreateRouteTable",
                        "ec2:DeleteRouteTable",
                        "ec2:DescribeRouteTables",
                        "ec2:CreateRoute",
                        "ec2:DeleteRoute",
                        "ec2:AssociateRouteTable",
                        "ec2:DisassociateRouteTable",
                        "ec2:AllocateAddress",
                        "ec2:ReleaseAddress",
                        "ec2:DescribeAddresses",
                        "ec2:CreateSecurityGroup",
                        "ec2:DeleteSecurityGroup",
                        "ec2:DescribeSecurityGroups",
                        "ec2:AuthorizeSecurityGroupIngress",
                        "ec2:AuthorizeSecurityGroupEgress",
                        "ec2:RevokeSecurityGroupIngress",
                        "ec2:RevokeSecurityGroupEgress",
                        "ec2:CreateTags",
                        "ec2:DeleteTags",
                        "ec2:DescribeTags",
                        "ec2:DescribeAvailabilityZones",
                        "ec2:CreateVpcEndpoint",
                        "ec2:DeleteVpcEndpoints",
                        "ec2:DescribeVpcEndpoints",
                        "ec2:ModifyVpcEndpoint",
                        "ec2:DescribeVpcEndpointServices",
                        "ec2:DescribePrefixLists"
                      ],
                      "Resource": "*"
                    }
                  ]
                }
              }
            },
            "SagebrushCLIPolicyIAM": {
              "Type": "AWS::IAM::ManagedPolicy",
              "Properties": {
                "ManagedPolicyName": "SagebrushCLIPolicyIAM",
                "Description": "IAM permissions for Sagebrush CLI",
                "PolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Sid": "IAMAccessForCloudFormation",
                      "Effect": "Allow",
                      "Action": [
                        "iam:CreateRole",
                        "iam:DeleteRole",
                        "iam:GetRole",
                        "iam:UpdateRole",
                        "iam:PutRolePolicy",
                        "iam:DeleteRolePolicy",
                        "iam:GetRolePolicy",
                        "iam:AttachRolePolicy",
                        "iam:DetachRolePolicy",
                        "iam:ListAttachedRolePolicies",
                        "iam:ListRolePolicies",
                        "iam:CreatePolicy",
                        "iam:DeletePolicy",
                        "iam:GetPolicy",
                        "iam:GetPolicyVersion",
                        "iam:ListPolicyVersions",
                        "iam:CreatePolicyVersion",
                        "iam:DeletePolicyVersion",
                        "iam:PassRole",
                        "iam:TagRole",
                        "iam:UntagRole",
                        "iam:TagPolicy",
                        "iam:UntagPolicy",
                        "iam:CreateServiceLinkedRole",
                        "iam:DeleteServiceLinkedRole",
                        "iam:GetServiceLinkedRoleDeletionStatus",
                        "iam:CreateOpenIDConnectProvider",
                        "iam:DeleteOpenIDConnectProvider",
                        "iam:GetOpenIDConnectProvider",
                        "iam:ListOpenIDConnectProviders",
                        "iam:TagOpenIDConnectProvider",
                        "iam:UntagOpenIDConnectProvider",
                        "iam:UpdateOpenIDConnectProviderThumbprint"
                      ],
                      "Resource": "*"
                    },
                    {
                      "Sid": "IAMUserManagement",
                      "Effect": "Allow",
                      "Action": [
                        "iam:CreateUser",
                        "iam:DeleteUser",
                        "iam:GetUser",
                        "iam:UpdateUser",
                        "iam:ListUsers",
                        "iam:CreateLoginProfile",
                        "iam:DeleteLoginProfile",
                        "iam:GetLoginProfile",
                        "iam:UpdateLoginProfile",
                        "iam:CreateAccessKey",
                        "iam:DeleteAccessKey",
                        "iam:ListAccessKeys",
                        "iam:UpdateAccessKey",
                        "iam:AttachUserPolicy",
                        "iam:DetachUserPolicy",
                        "iam:ListAttachedUserPolicies",
                        "iam:PutUserPolicy",
                        "iam:DeleteUserPolicy",
                        "iam:GetUserPolicy",
                        "iam:ListUserPolicies",
                        "iam:TagUser",
                        "iam:UntagUser"
                      ],
                      "Resource": "*"
                    }
                  ]
                }
              }
            }
          },
          "Outputs": {
            "RoleArn": {
              "Description": "ARN of the SagebrushCLIRole",
              "Value": { "Fn::GetAtt": ["SagebrushCLIRole", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RoleArn" }
              }
            },
            "RoleName": {
              "Description": "Name of the SagebrushCLIRole",
              "Value": { "Ref": "SagebrushCLIRole" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RoleName" }
              }
            }
          }
        }
        """
}
