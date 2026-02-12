import Foundation

/// CloudFormation stack to create RDS/Aurora prerequisites in child accounts
struct RDSPrerequisitesStack: Stack {
    var templateBody: String {
        """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "RDS/Aurora prerequisites - Service-Linked Roles and permissions",
          "Resources": {
            "RDSServiceLinkedRole": {
              "Type": "AWS::IAM::ServiceLinkedRole",
              "Properties": {
                "AWSServiceName": "rds.amazonaws.com",
                "Description": "Service-linked role for Amazon RDS"
              }
            }
          },
          "Outputs": {
            "RDSServiceLinkedRoleArn": {
              "Description": "ARN of the RDS service-linked role",
              "Value": {
                "Fn::GetAtt": ["RDSServiceLinkedRole", "Arn"]
              }
            }
          }
        }
        """
    }
}
