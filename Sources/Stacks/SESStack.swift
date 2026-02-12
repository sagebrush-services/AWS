import Foundation

/// CloudFormation stack for AWS SES (Simple Email Service) domain and email verification
/// Reference: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-ses-emailidentity.html
struct SESStack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "AWS SES domain and email identity verification with DKIM",
          "Parameters": {
            "DomainName": {
              "Description": "The domain name to verify for SES (e.g., sagebrush.services)",
              "Type": "String",
              "Default": "sagebrush.services",
              "AllowedPattern": "^([a-z0-9]+(-[a-z0-9]+)*\\\\.)+[a-z]{2,}$",
              "ConstraintDescription": "Must be a valid domain name"
            },
            "EmailAddress": {
              "Description": "Email address to verify for sending (e.g., support@sagebrush.services)",
              "Type": "String",
              "Default": "support@sagebrush.services",
              "AllowedPattern": "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\\\.[a-zA-Z]{2,}$",
              "ConstraintDescription": "Must be a valid email address"
            }
          },
          "Resources": {
            "DomainIdentity": {
              "Type": "AWS::SES::EmailIdentity",
              "Properties": {
                "EmailIdentity": { "Ref": "DomainName" },
                "DkimSigningAttributes": {
                  "NextSigningKeyLength": "RSA_2048_BIT"
                },
                "DkimAttributes": {
                  "SigningEnabled": true
                }
              }
            },
            "EmailIdentity": {
              "Type": "AWS::SES::EmailIdentity",
              "Properties": {
                "EmailIdentity": { "Ref": "EmailAddress" }
              }
            }
          },
          "Outputs": {
            "DomainIdentityArn": {
              "Description": "ARN of the SES domain identity",
              "Value": { "Fn::GetAtt": ["DomainIdentity", "DkimDNSTokenName1"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DomainIdentityArn" }
              }
            },
            "EmailIdentityArn": {
              "Description": "ARN of the SES email identity",
              "Value": { "Ref": "EmailIdentity" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-EmailIdentityArn" }
              }
            },
            "DKIMToken1": {
              "Description": "DKIM Token 1 for DNS CNAME record",
              "Value": { "Fn::GetAtt": ["DomainIdentity", "DkimDNSTokenName1"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DKIMToken1" }
              }
            },
            "DKIMToken2": {
              "Description": "DKIM Token 2 for DNS CNAME record",
              "Value": { "Fn::GetAtt": ["DomainIdentity", "DkimDNSTokenName2"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DKIMToken2" }
              }
            },
            "DKIMToken3": {
              "Description": "DKIM Token 3 for DNS CNAME record",
              "Value": { "Fn::GetAtt": ["DomainIdentity", "DkimDNSTokenName3"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DKIMToken3" }
              }
            },
            "DKIMValue1": {
              "Description": "DKIM Value 1 for DNS CNAME record",
              "Value": { "Fn::GetAtt": ["DomainIdentity", "DkimDNSTokenValue1"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DKIMValue1" }
              }
            },
            "DKIMValue2": {
              "Description": "DKIM Value 2 for DNS CNAME record",
              "Value": { "Fn::GetAtt": ["DomainIdentity", "DkimDNSTokenValue2"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DKIMValue2" }
              }
            },
            "DKIMValue3": {
              "Description": "DKIM Value 3 for DNS CNAME record",
              "Value": { "Fn::GetAtt": ["DomainIdentity", "DkimDNSTokenValue3"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DKIMValue3" }
              }
            }
          }
        }
        """
}
