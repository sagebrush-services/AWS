import Foundation

/// CloudFormation stack for creating an AWS Budget with cost alerts
struct BudgetStack: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "AWS Budget with cost alerts and notifications",
          "Parameters": {
            "BudgetName": {
              "Description": "Name of the budget",
              "Type": "String",
              "Default": "MonthlyBudget"
            },
            "BudgetAmount": {
              "Description": "Monthly budget amount in USD",
              "Type": "Number",
              "Default": 100,
              "MinValue": 1
            },
            "EmailAddress": {
              "Description": "Email address for budget notifications",
              "Type": "String",
              "AllowedPattern": "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\\\.[a-zA-Z]{2,}$",
              "ConstraintDescription": "Must be a valid email address"
            },
            "ThresholdPercentage": {
              "Description": "Alert threshold as percentage of budget (e.g., 80 for 80%)",
              "Type": "Number",
              "Default": 80,
              "MinValue": 1,
              "MaxValue": 100
            }
          },
          "Resources": {
            "BudgetNotificationTopic": {
              "Type": "AWS::SNS::Topic",
              "Properties": {
                "TopicName": {
                  "Fn::Sub": "${AWS::StackName}-Notifications"
                },
                "DisplayName": {
                  "Fn::Sub": "${BudgetName} Budget Alerts"
                },
                "Subscription": [
                  {
                    "Endpoint": { "Ref": "EmailAddress" },
                    "Protocol": "email"
                  }
                ]
              }
            },
            "MonthlyBudget": {
              "Type": "AWS::Budgets::Budget",
              "Properties": {
                "Budget": {
                  "BudgetName": { "Ref": "BudgetName" },
                  "BudgetLimit": {
                    "Amount": { "Ref": "BudgetAmount" },
                    "Unit": "USD"
                  },
                  "TimeUnit": "MONTHLY",
                  "BudgetType": "COST",
                  "CostTypes": {
                    "IncludeTax": true,
                    "IncludeSubscription": true,
                    "IncludeRefund": false,
                    "IncludeCredit": false,
                    "IncludeDiscount": true,
                    "IncludeRecurring": true,
                    "IncludeOtherSubscription": true,
                    "IncludeSupport": true,
                    "IncludeUpfront": true,
                    "UseBlended": false,
                    "UseAmortized": false
                  }
                },
                "NotificationsWithSubscribers": [
                  {
                    "Notification": {
                      "NotificationType": "ACTUAL",
                      "ComparisonOperator": "GREATER_THAN",
                      "Threshold": { "Ref": "ThresholdPercentage" },
                      "ThresholdType": "PERCENTAGE"
                    },
                    "Subscribers": [
                      {
                        "SubscriptionType": "SNS",
                        "Address": { "Ref": "BudgetNotificationTopic" }
                      },
                      {
                        "SubscriptionType": "EMAIL",
                        "Address": { "Ref": "EmailAddress" }
                      }
                    ]
                  },
                  {
                    "Notification": {
                      "NotificationType": "FORECASTED",
                      "ComparisonOperator": "GREATER_THAN",
                      "Threshold": 100,
                      "ThresholdType": "PERCENTAGE"
                    },
                    "Subscribers": [
                      {
                        "SubscriptionType": "SNS",
                        "Address": { "Ref": "BudgetNotificationTopic" }
                      },
                      {
                        "SubscriptionType": "EMAIL",
                        "Address": { "Ref": "EmailAddress" }
                      }
                    ]
                  }
                ]
              }
            }
          },
          "Outputs": {
            "BudgetName": {
              "Description": "Name of the budget",
              "Value": { "Ref": "BudgetName" }
            },
            "BudgetAmount": {
              "Description": "Monthly budget amount in USD",
              "Value": { "Ref": "BudgetAmount" }
            },
            "NotificationTopicArn": {
              "Description": "ARN of the SNS topic for budget notifications",
              "Value": { "Ref": "BudgetNotificationTopic" }
            },
            "ThresholdPercentage": {
              "Description": "Alert threshold percentage",
              "Value": { "Ref": "ThresholdPercentage" }
            }
          }
        }
        """
}
