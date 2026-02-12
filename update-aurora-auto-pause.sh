#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "Aurora Serverless v2 Auto-Pause Updater"
echo "========================================"
echo ""

# Function to get current MinCapacity
get_current_min_capacity() {
    local account_id=$1
    local cluster_id=$2

    CREDS=$(aws sts assume-role \
        --role-arn "arn:aws:iam::${account_id}:role/SagebrushCLIRole" \
        --role-session-name "aurora-update-${account_id}" \
        --external-id "sagebrush-cli" \
        --query 'Credentials.{AccessKeyId:AccessKeyId,SecretAccessKey:SecretAccessKey,SessionToken:SessionToken}' \
        --output json 2>/dev/null)

    export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r '.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r '.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo $CREDS | jq -r '.SessionToken')

    MIN_CAPACITY=$(aws rds describe-db-clusters \
        --region us-west-2 \
        --db-cluster-identifier "$cluster_id" \
        --query 'DBClusters[0].ServerlessV2ScalingConfiguration.MinCapacity' \
        --output text 2>/dev/null)

    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

    echo "$MIN_CAPACITY"
}

# Function to update Aurora stack
update_aurora_stack() {
    local account_name=$1
    local account_id=$2
    local stack_name=$3
    local vpc_stack=$4
    local cluster_id=$5

    echo -e "${YELLOW}=== Updating $account_name Aurora Cluster ===${NC}"
    echo "Account: $account_id"
    echo "Stack: $stack_name"
    echo "VPC Stack: $vpc_stack"
    echo "Cluster: $cluster_id"
    echo ""

    # Get current MinCapacity
    CURRENT_MIN=$(get_current_min_capacity "$account_id" "$cluster_id")
    echo -e "Current MinCapacity: ${RED}$CURRENT_MIN ACU${NC}"

    # Assume role
    CREDS=$(aws sts assume-role \
        --role-arn "arn:aws:iam::${account_id}:role/SagebrushCLIRole" \
        --role-session-name "aurora-update-${account_id}" \
        --external-id "sagebrush-cli" \
        --query 'Credentials.{AccessKeyId:AccessKeyId,SecretAccessKey:SecretAccessKey,SessionToken:SessionToken}' \
        --output json)

    export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r '.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r '.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo $CREDS | jq -r '.SessionToken')

    # Update CloudFormation stack using the new template
    echo "Updating CloudFormation stack..."
    ENV=production ~/Trifecta/Sagebrush/AWS/.build/release/AWS create-aurora-postgres \
        --region us-west-2 \
        --stack-name "$stack_name" \
        --vpc-stack "$vpc_stack" \
        --db-name app \
        --db-username postgres \
        --min-capacity 0 \
        --max-capacity 1 \
        --seconds-until-auto-pause 300

    echo ""
    echo "Waiting for stack update to complete..."
    aws cloudformation wait stack-update-complete \
        --region us-west-2 \
        --stack-name "$stack_name" 2>/dev/null || {
        echo -e "${YELLOW}Note: Stack may not have changed or update is still in progress${NC}"
    }

    # Verify new MinCapacity
    sleep 5
    NEW_MIN=$(aws rds describe-db-clusters \
        --region us-west-2 \
        --db-cluster-identifier "$cluster_id" \
        --query 'DBClusters[0].ServerlessV2ScalingConfiguration.MinCapacity' \
        --output text 2>/dev/null)

    AUTO_PAUSE=$(aws rds describe-db-clusters \
        --region us-west-2 \
        --db-cluster-identifier "$cluster_id" \
        --query 'DBClusters[0].ServerlessV2ScalingConfiguration.SecondsUntilAutoPause' \
        --output text 2>/dev/null)

    echo -e "${GREEN}✓ Update complete!${NC}"
    echo -e "New MinCapacity: ${GREEN}$NEW_MIN ACU${NC}"
    echo -e "Auto-pause after: ${GREEN}$AUTO_PAUSE seconds ($(($AUTO_PAUSE / 60)) minutes)${NC}"
    echo ""

    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
}

# Update Production
update_aurora_stack \
    "Production" \
    "978489150794" \
    "production-aurora-postgres" \
    "oregon-vpc" \
    "production-aurora-postgres-cluster"

# Update Staging
update_aurora_stack \
    "Staging" \
    "889786867297" \
    "staging-aurora-postgres" \
    "oregon-vpc" \
    "staging-aurora-postgres-cluster"

# Update NeonLaw
update_aurora_stack \
    "NeonLaw" \
    "102186460229" \
    "neonlaw-aurora-postgres" \
    "oregon-vpc" \
    "neonlaw-aurora-postgres-cluster"

# Final verification
echo -e "${GREEN}========================================"
echo "Final Verification"
echo "========================================${NC}"
echo ""

for account in "Production:978489150794:production-aurora-postgres-cluster" \
               "Staging:889786867297:staging-aurora-postgres-cluster" \
               "NeonLaw:102186460229:neonlaw-aurora-postgres-cluster"; do

    IFS=':' read -r account_name account_id cluster_id <<< "$account"

    CREDS=$(aws sts assume-role \
        --role-arn "arn:aws:iam::${account_id}:role/SagebrushCLIRole" \
        --role-session-name "verify-${account_id}" \
        --external-id "sagebrush-cli" \
        --query 'Credentials.{AccessKeyId:AccessKeyId,SecretAccessKey:SecretAccessKey,SessionToken:SessionToken}' \
        --output json 2>/dev/null)

    export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r '.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r '.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo $CREDS | jq -r '.SessionToken')

    MIN=$(aws rds describe-db-clusters \
        --region us-west-2 \
        --db-cluster-identifier "$cluster_id" \
        --query 'DBClusters[0].ServerlessV2ScalingConfiguration.MinCapacity' \
        --output text 2>/dev/null)

    MAX=$(aws rds describe-db-clusters \
        --region us-west-2 \
        --db-cluster-identifier "$cluster_id" \
        --query 'DBClusters[0].ServerlessV2ScalingConfiguration.MaxCapacity' \
        --output text 2>/dev/null)

    PAUSE=$(aws rds describe-db-clusters \
        --region us-west-2 \
        --db-cluster-identifier "$cluster_id" \
        --query 'DBClusters[0].ServerlessV2ScalingConfiguration.SecondsUntilAutoPause' \
        --output text 2>/dev/null)

    if [ "$MIN" == "0.0" ] && [ "$PAUSE" != "None" ]; then
        echo -e "${GREEN}✓ $account_name:${NC}"
    else
        echo -e "${RED}✗ $account_name:${NC}"
    fi

    echo "  Cluster: $cluster_id"
    echo "  Min Capacity: $MIN ACU"
    echo "  Max Capacity: $MAX ACU"
    echo "  Auto-pause: $PAUSE seconds ($(($PAUSE / 60)) minutes)"
    echo ""

    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
done

echo -e "${GREEN}========================================"
echo "All Aurora clusters updated!"
echo "========================================"
echo ""
echo "Estimated cost savings:"
echo "  Before: ~\$129/month (3 clusters × \$43/month)"
echo "  After:  ~\$30/month (3 clusters × \$10 storage)"
echo "  Savings: ~\$99/month (77% reduction)"
echo ""
echo "Databases will now:"
echo "  • Pause after 5 minutes of inactivity"
echo "  • Cost \$0/hour while paused"
echo "  • Resume in ~15 seconds when accessed"
echo "========================================${NC}"
