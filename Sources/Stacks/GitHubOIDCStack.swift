import Foundation

/// CloudFormation stack for GitHub OIDC provider and IAM role for GitHub Actions
struct GitHubOIDCStack: Stack {
    var templateBody: String {
        """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "GitHub OIDC provider and IAM role for GitHub Actions to push to CodeCommit",
          "Parameters": {
            "GitHubOrganization": {
              "Type": "String",
              "Description": "GitHub organization name",
              "Default": "NeonLawFoundation"
            },
            "GitHubRepository": {
              "Type": "String",
              "Description": "GitHub repository name",
              "Default": "Standards"
            },
            "CodeCommitRepositoryArn": {
              "Type": "String",
              "Description": "ARN of the CodeCommit repository to grant access to"
            }
          },
          "Resources": {
            "GitHubOIDCProvider": {
              "Type": "AWS::IAM::OIDCProvider",
              "Properties": {
                "Url": "https://token.actions.githubusercontent.com",
                "ClientIdList": [
                  "sts.amazonaws.com"
                ],
                "ThumbprintList": [
                  "6938fd4d98bab03faadb97b34396831e3780aea1",
                  "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "GitHubActionsOIDC"
                  }
                ]
              }
            },
            "GitHubActionsRole": {
              "Type": "AWS::IAM::Role",
              "Properties": {
                "RoleName": "GitHubActionsCodeCommitRole",
                "Description": "IAM role for GitHub Actions to push code to CodeCommit",
                "AssumeRolePolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Principal": {
                        "Federated": {
                          "Ref": "GitHubOIDCProvider"
                        }
                      },
                      "Action": "sts:AssumeRoleWithWebIdentity",
                      "Condition": {
                        "StringEquals": {
                          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                        },
                        "StringLike": {
                          "token.actions.githubusercontent.com:sub": {
                            "Fn::Sub": "repo:${GitHubOrganization}/${GitHubRepository}:*"
                          }
                        }
                      }
                    }
                  ]
                },
                "Policies": [
                  {
                    "PolicyName": "CodeCommitPushPullPolicy",
                    "PolicyDocument": {
                      "Version": "2012-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Action": [
                            "codecommit:GitPull",
                            "codecommit:GitPush"
                          ],
                          "Resource": {
                            "Ref": "CodeCommitRepositoryArn"
                          }
                        }
                      ]
                    }
                  }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "GitHubActionsCodeCommitRole"
                  }
                ]
              }
            }
          },
          "Outputs": {
            "OIDCProviderArn": {
              "Description": "ARN of the GitHub OIDC provider",
              "Value": {
                "Ref": "GitHubOIDCProvider"
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-OIDCProviderArn"
                }
              }
            },
            "GitHubActionsRoleArn": {
              "Description": "ARN of the IAM role for GitHub Actions",
              "Value": {
                "Fn::GetAtt": ["GitHubActionsRole", "Arn"]
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-GitHubActionsRoleArn"
                }
              }
            },
            "GitHubActionsRoleName": {
              "Description": "Name of the IAM role for GitHub Actions",
              "Value": {
                "Ref": "GitHubActionsRole"
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-GitHubActionsRoleName"
                }
              }
            }
          }
        }
        """
    }
}
