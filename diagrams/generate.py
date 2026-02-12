#!/usr/bin/env python3
"""
AWS Architecture Diagrams for Sagebrush Infrastructure

Generates detailed architecture diagrams for all 5 AWS accounts using the
official AWS architecture icons via the diagrams library.

Based on DEPLOYED_RESOURCES.md (Last Updated: 2026-01-01)
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import ECS, ECR, Lambda, Fargate
from diagrams.aws.database import RDS, Aurora, Elasticache
from diagrams.aws.network import VPC, ELB, Route53, CloudFront, VPCRouter, Endpoint
from diagrams.aws.storage import S3
from diagrams.aws.security import Cognito, SecretsManager, IAMRole
from diagrams.aws.engagement import SES
from diagrams.aws.devtools import Codecommit
from diagrams.aws.management import Organizations


def generate_organization_overview():
    """Generate overview diagram of AWS Organization structure"""
    with Diagram(
        "AWS Organization Overview",
        filename="outputs/00-organization-overview",
        show=False,
        direction="TB",
        graph_attr={"fontsize": "20", "bgcolor": "white"},
    ):
        with Cluster("AWS Organization"):
            org = Organizations("Organization\nRoot")

            with Cluster("Management Account\n(731099197338)"):
                mgmt = IAMRole("Management")

            with Cluster("Production Account\n(978489150794)"):
                prod = IAMRole("Production")

            with Cluster("Staging Account\n(889786867297)"):
                staging = IAMRole("Staging")

            with Cluster("Housekeeping Account\n(374073887345)"):
                housekeeping = IAMRole("Housekeeping")

            with Cluster("NeonLaw Account\n(102186460229)"):
                neonlaw = IAMRole("NeonLaw")

        org >> Edge(label="manages") >> [mgmt, prod, staging, housekeeping, neonlaw]
        housekeeping >> Edge(label="AssumeRole\nBillingReadRole", style="dashed") >> mgmt


def generate_management_account():
    """Management Account (731099197338) - Full production infrastructure"""
    with Diagram(
        "Management Account (731099197338)",
        filename="outputs/01-management-account",
        show=False,
        direction="LR",
        graph_attr={"fontsize": "20", "bgcolor": "white"},
    ):
        with Cluster("Custom VPC (10.111.0.0/16)"):
            vpc = VPC("oregon-vpc")

            with Cluster("Application Layer"):
                alb = ELB("sagebrush-alb")

                with Cluster("ECS Fargate"):
                    ecs_cluster = ECS("bazaar-cluster")
                    fargate_service = Fargate("bazaar-service\n1 task running")

                with Cluster("Container Registry"):
                    ecr_bazaar = ECR("bazaar")
                    ecr_destined = ECR("destined")

            with Cluster("Data Layer"):
                rds = RDS("oregon-rds-postgres\nPostgreSQL 17.4\ndb.t3.micro")
                redis = Elasticache("oregon-redis\nRedis")
                secrets = SecretsManager("oregon-secrets\nDB Credentials")

            with Cluster("Storage"):
                s3_public = S3("sagebrush-public-bucket")
                s3_mailroom = S3("sagebrush-mailroom-bucket")

        with Cluster("Edge & DNS"):
            cloudfront = CloudFront("sagebrush-brochure-cloudfront")
            route53 = Route53("sagebrush.services")

        with Cluster("Authentication"):
            cognito_dev = Cognito("sagebrush-cognito-dev")
            cognito_prod = Cognito("sagebrush-cognito-prod")
            cognito_main = Cognito("sagebrush-cognito")

        with Cluster("IAM"):
            cli_role = IAMRole("SagebrushCLIRole\nCross-account CLI")
            billing_role = IAMRole("BillingReadRole\nCost Explorer Access")

        # Connections
        route53 >> cloudfront >> alb
        alb >> ecs_cluster >> fargate_service
        fargate_service >> [rds, redis]
        fargate_service >> Edge(label="pulls") >> [ecr_bazaar, ecr_destined]
        fargate_service >> secrets
        fargate_service >> [s3_public, s3_mailroom]


def generate_production_account():
    """Production Account (978489150794) - Aurora Serverless + Lambda"""
    with Diagram(
        "Production Account (978489150794)",
        filename="outputs/02-production-account",
        show=False,
        direction="TB",
        graph_attr={"fontsize": "20", "bgcolor": "white"},
    ):
        with Cluster("Custom VPC (10.20.0.0/16)"):
            vpc = VPC("oregon-vpc")

            with Cluster("Private Subnets"):
                with Cluster("Database"):
                    aurora = Aurora("production-aurora-postgres\nAurora Serverless v2\nPostgreSQL 16.4\n0.0-1.0 ACU")
                    aurora_secrets = SecretsManager("production-aurora-postgres-secret")

                with Cluster("Compute"):
                    migration_lambda = Lambda("MigrationRunner\nSwift Runtime\nARM64/Graviton\n512 MB")

            with Cluster("VPC Endpoints"):
                s3_endpoint = Endpoint("S3 Gateway\nFREE")

        with Cluster("Storage"):
            lambda_artifacts = S3("standards-lambda-artifacts-978489150794")

        with Cluster("Cross-Account Access"):
            console_role = IAMRole("ConsoleAdminAccess\nFrom Management Account")

        # Connections
        migration_lambda >> Edge(label="runs migrations") >> aurora
        migration_lambda >> Edge(label="reads credentials") >> aurora_secrets
        migration_lambda >> Edge(label="reads code") >> lambda_artifacts
        vpc >> s3_endpoint >> lambda_artifacts


def generate_staging_account():
    """Staging Account (889786867297) - Aurora Serverless + Lambda"""
    with Diagram(
        "Staging Account (889786867297)",
        filename="outputs/03-staging-account",
        show=False,
        direction="TB",
        graph_attr={"fontsize": "20", "bgcolor": "white"},
    ):
        with Cluster("Custom VPC (10.10.0.0/16)"):
            vpc = VPC("oregon-vpc")

            with Cluster("Private Subnets"):
                with Cluster("Database"):
                    aurora = Aurora("staging-aurora-postgres\nAurora Serverless v2\nPostgreSQL 16.4\n0.0-1.0 ACU")
                    aurora_secrets = SecretsManager("staging-aurora-postgres-secret")

                with Cluster("Compute"):
                    migration_lambda = Lambda("MigrationRunner\nSwift Runtime\nARM64/Graviton\n512 MB")

            with Cluster("VPC Endpoints"):
                s3_endpoint = Endpoint("S3 Gateway\nFREE")

        with Cluster("Storage"):
            lambda_artifacts = S3("standards-lambda-artifacts-889786867297")

        with Cluster("Governance"):
            scp = Organizations("Service Control Policy\nRegion Restriction\nus-west-2, us-east-1")

        with Cluster("Cross-Account Access"):
            console_role = IAMRole("ConsoleAdminAccess\nFrom Management Account")

        # Connections
        migration_lambda >> Edge(label="runs migrations") >> aurora
        migration_lambda >> Edge(label="reads credentials") >> aurora_secrets
        migration_lambda >> Edge(label="reads code") >> lambda_artifacts
        vpc >> s3_endpoint >> lambda_artifacts


def generate_housekeeping_account():
    """Housekeeping Account (374073887345) - Daily billing automation"""
    with Diagram(
        "Housekeeping Account (374073887345)",
        filename="outputs/04-housekeeping-account",
        show=False,
        direction="LR",
        graph_attr={"fontsize": "20", "bgcolor": "white"},
    ):
        with Cluster("Compute"):
            daily_billing = Lambda("DailyBilling\nSwift Runtime\nARM64/Graviton\n128 MB\nRuns daily at midnight UTC")

        with Cluster("Storage"):
            lambda_bucket = S3("housekeeping-lambda-bucket\nDeployment packages")

        with Cluster("Email Infrastructure"):
            ses = SES("support@sagebrush.services\nDKIM enabled\nSandbox mode")

        with Cluster("Cross-Account Access"):
            mgmt_billing_role = IAMRole("BillingReadRole\nIn Management Account\n(731099197338)")

        # Connections
        daily_billing >> Edge(label="reads code") >> lambda_bucket
        daily_billing >> Edge(label="AssumeRole", style="dashed") >> mgmt_billing_role
        daily_billing >> Edge(label="sends reports") >> ses


def generate_neonlaw_account():
    """NeonLaw Account (102186460229) - Aurora Serverless + Lambda + CodeCommit"""
    with Diagram(
        "NeonLaw Account (102186460229)",
        filename="outputs/05-neonlaw-account",
        show=False,
        direction="TB",
        graph_attr={"fontsize": "20", "bgcolor": "white"},
    ):
        with Cluster("Custom VPC (10.30.0.0/16)"):
            vpc = VPC("oregon-vpc")

            with Cluster("Private Subnets"):
                with Cluster("Database"):
                    aurora = Aurora("neonlaw-aurora-postgres\nAurora Serverless v2\nPostgreSQL 16.4\n0.0-1.0 ACU")
                    aurora_secrets = SecretsManager("neonlaw-aurora-postgres-secret")

                with Cluster("Compute"):
                    migration_lambda = Lambda("MigrationRunner\nSwift Runtime\nARM64/Graviton\n512 MB")

            with Cluster("VPC Endpoints"):
                s3_endpoint = Endpoint("S3 Gateway\nFREE")

        with Cluster("Storage"):
            lambda_artifacts = S3("standards-lambda-artifacts-102186460229")

        with Cluster("Code Repositories"):
            with Cluster("CodeCommit"):
                repo1 = Codecommit("GreenCrossFarmacy")
                repo2 = Codecommit("NLF")
                repo3 = Codecommit("Sagebrush")
                repo4 = Codecommit("SagebrushHoldingCompany")
                repo5 = Codecommit("ShookEstate")

        with Cluster("Cross-Account Access"):
            console_role = IAMRole("ConsoleAdminAccess\nFrom Management Account")

        # Connections
        migration_lambda >> Edge(label="runs migrations") >> aurora
        migration_lambda >> Edge(label="reads credentials") >> aurora_secrets
        migration_lambda >> Edge(label="reads code") >> lambda_artifacts
        vpc >> s3_endpoint >> lambda_artifacts


def main():
    """Generate all diagrams"""
    print("Generating AWS architecture diagrams...")
    print("=" * 60)

    print("✓ Generating organization overview...")
    generate_organization_overview()

    print("✓ Generating Management Account diagram...")
    generate_management_account()

    print("✓ Generating Production Account diagram...")
    generate_production_account()

    print("✓ Generating Staging Account diagram...")
    generate_staging_account()

    print("✓ Generating Housekeeping Account diagram...")
    generate_housekeeping_account()

    print("✓ Generating NeonLaw Account diagram...")
    generate_neonlaw_account()

    print("=" * 60)
    print("All diagrams generated successfully!")
    print("\nOutput files:")
    print("  - outputs/00-organization-overview.png")
    print("  - outputs/01-management-account.png")
    print("  - outputs/02-production-account.png")
    print("  - outputs/03-staging-account.png")
    print("  - outputs/04-housekeeping-account.png")
    print("  - outputs/05-neonlaw-account.png")


if __name__ == "__main__":
    main()
