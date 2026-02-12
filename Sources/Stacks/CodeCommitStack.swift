import Foundation

/// CloudFormation stack for creating a CodeCommit repository
struct CodeCommitStack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "CodeCommit repository with main branch",
          "Parameters": {
            "RepositoryName": {
              "Description": "Name of the CodeCommit repository",
              "Type": "String",
              "MinLength": 1,
              "MaxLength": 100,
              "AllowedPattern": "[a-zA-Z0-9._-]+",
              "ConstraintDescription": "Must contain only alphanumeric characters, periods, hyphens, and underscores"
            }
          },
          "Resources": {
            "CodeCommitRepository": {
              "Type": "AWS::CodeCommit::Repository",
              "Properties": {
                "RepositoryName": { "Ref": "RepositoryName" }
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
              "Description": "HTTP clone URL",
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
            }
          }
        }
        """
}
