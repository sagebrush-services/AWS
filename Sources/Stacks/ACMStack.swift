import Foundation

/// CloudFormation stack for creating ACM (AWS Certificate Manager) SSL/TLS certificates
/// Reference: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-certificatemanager-certificate.html
struct ACMStack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "ACM certificate with DNS validation for HTTPS",
          "Parameters": {
            "DomainName": {
              "Description": "The fully qualified domain name (e.g., www.example.com)",
              "Type": "String",
              "AllowedPattern": "^([a-z0-9]+(-[a-z0-9]+)*\\.)+[a-z]{2,}$",
              "ConstraintDescription": "Must be a valid domain name"
            },
            "Route53HostedZoneId": {
              "Description": "Route53 hosted zone ID for DNS validation",
              "Type": "String"
            },
            "SubjectAlternativeNames": {
              "Description": "Comma-separated list of additional domain names (optional, e.g., *.example.com)",
              "Type": "CommaDelimitedList",
              "Default": ""
            }
          },
          "Conditions": {
            "HasSubjectAlternativeNames": {
              "Fn::Not": [
                {
                  "Fn::Equals": [
                    { "Fn::Select": [0, { "Ref": "SubjectAlternativeNames" }] },
                    ""
                  ]
                }
              ]
            }
          },
          "Resources": {
            "Certificate": {
              "Type": "AWS::CertificateManager::Certificate",
              "Properties": {
                "DomainName": { "Ref": "DomainName" },
                "SubjectAlternativeNames": {
                  "Fn::If": [
                    "HasSubjectAlternativeNames",
                    { "Ref": "SubjectAlternativeNames" },
                    { "Ref": "AWS::NoValue" }
                  ]
                },
                "ValidationMethod": "DNS",
                "DomainValidationOptions": [
                  {
                    "DomainName": { "Ref": "DomainName" },
                    "HostedZoneId": { "Ref": "Route53HostedZoneId" }
                  }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Ref": "DomainName" }
                  },
                  {
                    "Key": "ManagedBy",
                    "Value": "CloudFormation"
                  }
                ]
              }
            }
          },
          "Outputs": {
            "CertificateArn": {
              "Description": "ARN of the ACM certificate",
              "Value": { "Ref": "Certificate" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-CertificateArn" }
              }
            },
            "DomainName": {
              "Description": "Domain name of the certificate",
              "Value": { "Ref": "DomainName" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DomainName" }
              }
            }
          }
        }
        """
}
