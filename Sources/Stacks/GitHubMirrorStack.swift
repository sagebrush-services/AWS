import Foundation

/// CloudFormation stack for GitHub → CodeCommit mirroring infrastructure
///
/// Creates a complete solution for mirroring GitHub repositories to CodeCommit:
/// - CodeCommit repository for mirrored code
/// - IAM user for GitHub Actions authentication
/// - IAM policy with least privilege (GitPull/GitPush to this repo only)
/// - Access key for GitHub Actions to use
struct GitHubMirrorStack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "GitHub to CodeCommit mirroring infrastructure with IAM user and access keys",
          "Parameters": {
            "RepositoryName": {
              "Description": "Name of the CodeCommit repository (e.g., sagebrush-web)",
              "Type": "String",
              "MinLength": 1,
              "MaxLength": 100,
              "AllowedPattern": "[a-zA-Z0-9._-]+",
              "ConstraintDescription": "Must contain only alphanumeric characters, periods, hyphens, and underscores"
            },
            "Environment": {
              "Description": "Environment name (staging or production)",
              "Type": "String",
              "AllowedValues": ["staging", "production"],
              "Default": "staging"
            }
          },
          "Resources": {
            "CodeCommitRepository": {
              "Type": "AWS::CodeCommit::Repository",
              "Properties": {
                "RepositoryName": { "Ref": "RepositoryName" },
                "RepositoryDescription": {
                  "Fn::Sub": "${RepositoryName} - Mirrored from GitHub (${Environment})"
                },
                "Tags": [
                  {
                    "Key": "ManagedBy",
                    "Value": "CloudFormation"
                  },
                  {
                    "Key": "Environment",
                    "Value": { "Ref": "Environment" }
                  },
                  {
                    "Key": "Purpose",
                    "Value": "GitHubMirror"
                  }
                ]
              }
            },
            "GitHubActionsUser": {
              "Type": "AWS::IAM::User",
              "Properties": {
                "UserName": {
                  "Fn::Sub": "github-${RepositoryName}-${Environment}"
                },
                "Tags": [
                  {
                    "Key": "ManagedBy",
                    "Value": "CloudFormation"
                  },
                  {
                    "Key": "Environment",
                    "Value": { "Ref": "Environment" }
                  },
                  {
                    "Key": "Purpose",
                    "Value": "GitHubMirror"
                  },
                  {
                    "Key": "Repository",
                    "Value": { "Ref": "RepositoryName" }
                  }
                ]
              }
            },
            "GitHubActionsPolicy": {
              "Type": "AWS::IAM::Policy",
              "Properties": {
                "PolicyName": {
                  "Fn::Sub": "GithubMirrorPolicy-${RepositoryName}-${Environment}"
                },
                "PolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Sid": "CodeCommitGitAccess",
                      "Effect": "Allow",
                      "Action": [
                        "codecommit:GitPull",
                        "codecommit:GitPush"
                      ],
                      "Resource": {
                        "Fn::GetAtt": ["CodeCommitRepository", "Arn"]
                      }
                    }
                  ]
                },
                "Users": [
                  { "Ref": "GitHubActionsUser" }
                ]
              }
            },
            "GitHubActionsAccessKey": {
              "Type": "AWS::IAM::AccessKey",
              "Properties": {
                "UserName": { "Ref": "GitHubActionsUser" }
              }
            }
          },
          "Outputs": {
            "RepositoryName": {
              "Description": "Name of the CodeCommit repository",
              "Value": { "Fn::GetAtt": ["CodeCommitRepository", "Name"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RepositoryName" }
              }
            },
            "RepositoryArn": {
              "Description": "ARN of the CodeCommit repository",
              "Value": { "Fn::GetAtt": ["CodeCommitRepository", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RepositoryArn" }
              }
            },
            "CloneUrlHttp": {
              "Description": "HTTP clone URL for git-remote-codecommit",
              "Value": { "Fn::GetAtt": ["CodeCommitRepository", "CloneUrlHttp"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-CloneUrlHttp" }
              }
            },
            "CloneUrlSsh": {
              "Description": "SSH clone URL",
              "Value": { "Fn::GetAtt": ["CodeCommitRepository", "CloneUrlSsh"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-CloneUrlSsh" }
              }
            },
            "IAMUserName": {
              "Description": "Name of the IAM user for GitHub Actions",
              "Value": { "Ref": "GitHubActionsUser" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-IAMUserName" }
              }
            },
            "IAMUserArn": {
              "Description": "ARN of the IAM user",
              "Value": { "Fn::GetAtt": ["GitHubActionsUser", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-IAMUserArn" }
              }
            },
            "AccessKeyId": {
              "Description": "AWS Access Key ID for GitHub Actions secret AWS_ACCESS_KEY_ID",
              "Value": { "Ref": "GitHubActionsAccessKey" }
            },
            "SecretAccessKey": {
              "Description": "AWS Secret Access Key for GitHub Actions secret AWS_SECRET_ACCESS_KEY (only visible at creation time)",
              "Value": { "Fn::GetAtt": ["GitHubActionsAccessKey", "SecretAccessKey"] }
            }
          }
        }
        """
}
