import Foundation

/// CloudFormation stack for creating Route53 hosted zone and DNS records
/// Reference: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-route53-hostedzone.html
struct Route53Stack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "Route53 hosted zone for DNS management with optional DNS records",
          "Parameters": {
            "DomainName": {
              "Description": "The domain name for the hosted zone (e.g., sagebrush.services)",
              "Type": "String",
              "AllowedPattern": "^([a-z0-9]+(-[a-z0-9]+)*\\\\.)+[a-z]{2,}$",
              "ConstraintDescription": "Must be a valid domain name"
            },
            "HostedZoneComment": {
              "Description": "Comment for the hosted zone",
              "Type": "String",
              "Default": "Managed by CloudFormation"
            },
            "WWWRecordTarget": {
              "Description": "Target DNS name for www A record (e.g., ALB DNS name). Leave empty to skip.",
              "Type": "String",
              "Default": ""
            },
            "StagingRecordTarget": {
              "Description": "Target DNS name for staging A record (e.g., ALB DNS name). Leave empty to skip.",
              "Type": "String",
              "Default": ""
            },
            "MXRecordValue": {
              "Description": "MX record value (e.g., '10 inbound-smtp.us-west-2.amazonaws.com'). Leave empty to skip.",
              "Type": "String",
              "Default": ""
            },
            "SPFRecord": {
              "Description": "SPF TXT record value (e.g., 'v=spf1 include:amazonses.com ~all'). Leave empty to skip.",
              "Type": "String",
              "Default": ""
            },
            "DMARCRecord": {
              "Description": "DMARC TXT record value (e.g., 'v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com'). Leave empty to skip.",
              "Type": "String",
              "Default": ""
            },
            "DKIMToken1": {
              "Description": "SES DKIM token 1 (name part). Leave empty to skip.",
              "Type": "String",
              "Default": ""
            },
            "DKIMValue1": {
              "Description": "SES DKIM value 1 (target part). Leave empty to skip.",
              "Type": "String",
              "Default": ""
            },
            "DKIMToken2": {
              "Description": "SES DKIM token 2 (name part). Leave empty to skip.",
              "Type": "String",
              "Default": ""
            },
            "DKIMValue2": {
              "Description": "SES DKIM value 2 (target part). Leave empty to skip.",
              "Type": "String",
              "Default": ""
            },
            "DKIMToken3": {
              "Description": "SES DKIM token 3 (name part). Leave empty to skip.",
              "Type": "String",
              "Default": ""
            },
            "DKIMValue3": {
              "Description": "SES DKIM value 3 (target part). Leave empty to skip.",
              "Type": "String",
              "Default": ""
            }
          },
          "Conditions": {
            "CreateWWWRecord": {
              "Fn::Not": [{ "Fn::Equals": [{ "Ref": "WWWRecordTarget" }, ""] }]
            },
            "CreateStagingRecord": {
              "Fn::Not": [{ "Fn::Equals": [{ "Ref": "StagingRecordTarget" }, ""] }]
            },
            "CreateMXRecord": {
              "Fn::Not": [{ "Fn::Equals": [{ "Ref": "MXRecordValue" }, ""] }]
            },
            "CreateSPFRecord": {
              "Fn::Not": [{ "Fn::Equals": [{ "Ref": "SPFRecord" }, ""] }]
            },
            "CreateDMARCRecord": {
              "Fn::Not": [{ "Fn::Equals": [{ "Ref": "DMARCRecord" }, ""] }]
            },
            "CreateDKIM1": {
              "Fn::And": [
                { "Fn::Not": [{ "Fn::Equals": [{ "Ref": "DKIMToken1" }, ""] }] },
                { "Fn::Not": [{ "Fn::Equals": [{ "Ref": "DKIMValue1" }, ""] }] }
              ]
            },
            "CreateDKIM2": {
              "Fn::And": [
                { "Fn::Not": [{ "Fn::Equals": [{ "Ref": "DKIMToken2" }, ""] }] },
                { "Fn::Not": [{ "Fn::Equals": [{ "Ref": "DKIMValue2" }, ""] }] }
              ]
            },
            "CreateDKIM3": {
              "Fn::And": [
                { "Fn::Not": [{ "Fn::Equals": [{ "Ref": "DKIMToken3" }, ""] }] },
                { "Fn::Not": [{ "Fn::Equals": [{ "Ref": "DKIMValue3" }, ""] }] }
              ]
            }
          },
          "Resources": {
            "HostedZone": {
              "Type": "AWS::Route53::HostedZone",
              "Properties": {
                "Name": { "Ref": "DomainName" },
                "HostedZoneConfig": {
                  "Comment": { "Ref": "HostedZoneComment" }
                },
                "HostedZoneTags": [
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
            },
            "WWWARecord": {
              "Type": "AWS::Route53::RecordSet",
              "Condition": "CreateWWWRecord",
              "Properties": {
                "HostedZoneId": { "Ref": "HostedZone" },
                "Name": { "Fn::Sub": "www.${DomainName}" },
                "Type": "CNAME",
                "TTL": "300",
                "ResourceRecords": [{ "Ref": "WWWRecordTarget" }]
              }
            },
            "StagingARecord": {
              "Type": "AWS::Route53::RecordSet",
              "Condition": "CreateStagingRecord",
              "Properties": {
                "HostedZoneId": { "Ref": "HostedZone" },
                "Name": { "Fn::Sub": "staging.${DomainName}" },
                "Type": "CNAME",
                "TTL": "300",
                "ResourceRecords": [{ "Ref": "StagingRecordTarget" }]
              }
            },
            "MXRecord": {
              "Type": "AWS::Route53::RecordSet",
              "Condition": "CreateMXRecord",
              "Properties": {
                "HostedZoneId": { "Ref": "HostedZone" },
                "Name": { "Ref": "DomainName" },
                "Type": "MX",
                "TTL": "300",
                "ResourceRecords": [{ "Ref": "MXRecordValue" }]
              }
            },
            "SPFRecordSet": {
              "Type": "AWS::Route53::RecordSet",
              "Condition": "CreateSPFRecord",
              "Properties": {
                "HostedZoneId": { "Ref": "HostedZone" },
                "Name": { "Ref": "DomainName" },
                "Type": "TXT",
                "TTL": "300",
                "ResourceRecords": [{ "Fn::Sub": "\\"${SPFRecord}\\"" }]
              }
            },
            "DMARCRecordSet": {
              "Type": "AWS::Route53::RecordSet",
              "Condition": "CreateDMARCRecord",
              "Properties": {
                "HostedZoneId": { "Ref": "HostedZone" },
                "Name": { "Fn::Sub": "_dmarc.${DomainName}" },
                "Type": "TXT",
                "TTL": "300",
                "ResourceRecords": [{ "Fn::Sub": "\\"${DMARCRecord}\\"" }]
              }
            },
            "DKIM1CNAMERecord": {
              "Type": "AWS::Route53::RecordSet",
              "Condition": "CreateDKIM1",
              "Properties": {
                "HostedZoneId": { "Ref": "HostedZone" },
                "Name": { "Fn::Sub": "${DKIMToken1}._domainkey.${DomainName}" },
                "Type": "CNAME",
                "TTL": "300",
                "ResourceRecords": [{ "Fn::Sub": "${DKIMValue1}" }]
              }
            },
            "DKIM2CNAMERecord": {
              "Type": "AWS::Route53::RecordSet",
              "Condition": "CreateDKIM2",
              "Properties": {
                "HostedZoneId": { "Ref": "HostedZone" },
                "Name": { "Fn::Sub": "${DKIMToken2}._domainkey.${DomainName}" },
                "Type": "CNAME",
                "TTL": "300",
                "ResourceRecords": [{ "Fn::Sub": "${DKIMValue2}" }]
              }
            },
            "DKIM3CNAMERecord": {
              "Type": "AWS::Route53::RecordSet",
              "Condition": "CreateDKIM3",
              "Properties": {
                "HostedZoneId": { "Ref": "HostedZone" },
                "Name": { "Fn::Sub": "${DKIMToken3}._domainkey.${DomainName}" },
                "Type": "CNAME",
                "TTL": "300",
                "ResourceRecords": [{ "Fn::Sub": "${DKIMValue3}" }]
              }
            }
          },
          "Outputs": {
            "HostedZoneId": {
              "Description": "ID of the Route53 hosted zone",
              "Value": { "Ref": "HostedZone" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-HostedZoneId" }
              }
            },
            "NameServers": {
              "Description": "Name servers for the hosted zone",
              "Value": { "Fn::Join": [",", { "Fn::GetAtt": ["HostedZone", "NameServers"] }] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-NameServers" }
              }
            },
            "DomainName": {
              "Description": "Domain name of the hosted zone",
              "Value": { "Ref": "DomainName" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DomainName" }
              }
            }
          }
        }
        """
}
