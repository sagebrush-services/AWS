import Foundation

/// CloudFormation stack for creating EventBridge rules and targets
/// Reference: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-events-rule.html
struct EventBridgeStack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "EventBridge rule for scheduled events and cross-account event handling",
          "Parameters": {
            "RuleName": {
              "Description": "Name of the EventBridge rule",
              "Type": "String",
              "MinLength": 1,
              "MaxLength": 64,
              "AllowedPattern": "[a-zA-Z0-9-_]+",
              "ConstraintDescription": "Must contain only alphanumeric characters, hyphens, and underscores"
            },
            "RuleDescription": {
              "Description": "Description of the EventBridge rule",
              "Type": "String",
              "Default": "Managed by CloudFormation"
            },
            "ScheduleExpression": {
              "Description": "Schedule expression for the rule (e.g., rate(5 minutes) or cron(0 12 * * ? *))",
              "Type": "String",
              "Default": "rate(5 minutes)"
            },
            "TargetLambdaArn": {
              "Description": "ARN of the Lambda function to invoke (optional)",
              "Type": "String",
              "Default": ""
            }
          },
          "Conditions": {
            "HasLambdaTarget": {
              "Fn::Not": [{ "Fn::Equals": [{ "Ref": "TargetLambdaArn" }, ""] }]
            }
          },
          "Resources": {
            "EventRule": {
              "Type": "AWS::Events::Rule",
              "Properties": {
                "Name": { "Ref": "RuleName" },
                "Description": { "Ref": "RuleDescription" },
                "ScheduleExpression": { "Ref": "ScheduleExpression" },
                "State": "ENABLED",
                "Targets": {
                  "Fn::If": [
                    "HasLambdaTarget",
                    [
                      {
                        "Arn": { "Ref": "TargetLambdaArn" },
                        "Id": "LambdaTarget"
                      }
                    ],
                    { "Ref": "AWS::NoValue" }
                  ]
                }
              }
            },
            "LambdaInvokePermission": {
              "Type": "AWS::Lambda::Permission",
              "Condition": "HasLambdaTarget",
              "Properties": {
                "FunctionName": { "Ref": "TargetLambdaArn" },
                "Action": "lambda:InvokeFunction",
                "Principal": "events.amazonaws.com",
                "SourceArn": { "Fn::GetAtt": ["EventRule", "Arn"] }
              }
            }
          },
          "Outputs": {
            "EventRuleArn": {
              "Description": "ARN of the EventBridge rule",
              "Value": { "Fn::GetAtt": ["EventRule", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-EventRuleArn" }
              }
            },
            "EventRuleName": {
              "Description": "Name of the EventBridge rule",
              "Value": { "Ref": "RuleName" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-EventRuleName" }
              }
            }
          }
        }
        """
}
