import AsyncHTTPClient
import Foundation
import SotoCloudFormation
import SotoCore
import SotoRoute53
import Testing

@testable import AWS

@Suite("Route53 Integration Tests")
struct Route53IntegrationTests {
    @Test("Creates Route53 hosted zone with all DNS record types")
    func testCreateRoute53WithAllRecords() async throws {
        let configuration = AWSConfiguration()
        let cfClient = CloudFormationClient(configuration: configuration)

        // Create Route53 stack with all email records
        let parameters = [
            "DomainName": "test.sagebrush.services",
            "MXRecordValue": "10 inbound-smtp.us-east-1.amazonaws.com",
            "SPFRecord": "v=spf1 include:amazonses.com ~all",
            "DMARCRecord": "v=DMARC1; p=quarantine; rua=mailto:dmarc@test.sagebrush.services",
            "DKIMToken1": "test1",
            "DKIMValue1": "test1.dkim.amazonses.com",
            "DKIMToken2": "test2",
            "DKIMValue2": "test2.dkim.amazonses.com",
            "DKIMToken3": "test3",
            "DKIMValue3": "test3.dkim.amazonses.com",
        ]

        let stackName = "route53-integration-test-\(UUID().uuidString.prefix(8))"

        // Create stack
        print("🚀 Creating Route53 stack with all DNS records...")
        try await cfClient.upsertStack(
            stack: Route53Stack(),
            region: .useast1,
            stackName: stackName,
            parameters: parameters
        )
        print("✅ Route53 stack created successfully")

        do {
            // Get the hosted zone ID from stack outputs
            let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
            let awsClient = SotoCore.AWSClient(httpClient: httpClient)
            let cloudFormation = CloudFormation(
                client: awsClient,
                region: .useast1,
                endpoint: configuration.endpoint
            )

            let stacksResponse = try await cloudFormation.describeStacks(
                CloudFormation.DescribeStacksInput(stackName: stackName)
            )
            guard let stack = stacksResponse.stacks?.first,
                let outputs = stack.outputs
            else {
                Issue.record("Stack or outputs not found")
                return
            }

            let hostedZoneIdOutput = outputs.first { $0.outputKey == "HostedZoneId" }
            #expect(hostedZoneIdOutput != nil)

            guard let hostedZoneId = hostedZoneIdOutput?.outputValue else {
                Issue.record("HostedZoneId output not found")
                return
            }

            // Extract the zone ID from the full path (/hostedzone/ZXXXXX)
            let zoneId = hostedZoneId.split(separator: "/").last.map(String.init) ?? hostedZoneId

            // Verify DNS records using Route53 API
            let route53 = Route53(
                client: awsClient,
                endpoint: configuration.endpoint
            )
            let request = Route53.ListResourceRecordSetsRequest(
                hostedZoneId: zoneId
            )

            let response = try await route53.listResourceRecordSets(request)
            let records = response.resourceRecordSets

            // Verify MX record
            let mxRecords = records.filter { $0.type == Route53.RRType.mx }
            #expect(mxRecords.count == 1)
            #expect(
                mxRecords.first?.resourceRecords?.first?.value
                    == "10 inbound-smtp.us-east-1.amazonaws.com"
            )

            // Verify SPF TXT record
            let txtRecords = records.filter {
                $0.type == Route53.RRType.txt && $0.name == "test.sagebrush.services."
            }
            #expect(!txtRecords.isEmpty)
            let spfRecord = txtRecords.first {
                $0.resourceRecords?.first?.value.contains("spf1") == true
            }
            #expect(spfRecord != nil)
            #expect(spfRecord?.resourceRecords?.first?.value == "\"v=spf1 include:amazonses.com ~all\"")

            // Verify DMARC TXT record
            let dmarcRecords = records.filter {
                $0.type == Route53.RRType.txt && $0.name == "_dmarc.test.sagebrush.services."
            }
            #expect(dmarcRecords.count == 1)
            #expect(
                dmarcRecords.first?.resourceRecords?.first?.value
                    == "\"v=DMARC1; p=quarantine; rua=mailto:dmarc@test.sagebrush.services\""
            )

            // Verify DKIM CNAME records
            let dkimRecords = records.filter {
                $0.type == Route53.RRType.cname && $0.name.contains("_domainkey")
            }
            #expect(dkimRecords.count == 3)

            let dkim1 = dkimRecords.first { $0.name == "test1._domainkey.test.sagebrush.services." }
            #expect(dkim1 != nil)
            #expect(dkim1?.resourceRecords?.first?.value == "test1.dkim.amazonses.com")

            let dkim2 = dkimRecords.first { $0.name == "test2._domainkey.test.sagebrush.services." }
            #expect(dkim2 != nil)
            #expect(dkim2?.resourceRecords?.first?.value == "test2.dkim.amazonses.com")

            let dkim3 = dkimRecords.first { $0.name == "test3._domainkey.test.sagebrush.services." }
            #expect(dkim3 != nil)
            #expect(dkim3?.resourceRecords?.first?.value == "test3.dkim.amazonses.com")

            // Verify NS records exist
            let nsRecords = records.filter { $0.type == Route53.RRType.ns }
            #expect(nsRecords.count >= 1)

            // Verify SOA record exists
            let soaRecords = records.filter { $0.type == Route53.RRType.soa }
            #expect(soaRecords.count == 1)

            print("✅ All DNS records verified successfully!")

            // Cleanup AWS clients
            try await awsClient.shutdown()
            try await httpClient.shutdown()

        } catch {
            Issue.record("Failed to create or verify Route53 stack: \(error)")
            throw error
        }

        // Cleanup
        print("🧹 Cleaning up Route53 stack...")
        try await cfClient.deleteStack(stackName: stackName, region: .useast1)
    }

    @Test("Creates Route53 hosted zone without optional records")
    func testCreateRoute53HostedZoneOnly() async throws {
        let configuration = AWSConfiguration()
        let cfClient = CloudFormationClient(configuration: configuration)

        let parameters = [
            "DomainName": "minimal.sagebrush.services"
        ]

        let stackName = "route53-minimal-test-\(UUID().uuidString.prefix(8))"

        // Create stack
        print("🚀 Creating Route53 hosted zone (minimal)...")
        try await cfClient.upsertStack(
            stack: Route53Stack(),
            region: .useast1,
            stackName: stackName,
            parameters: parameters
        )
        print("✅ Route53 stack created successfully")

        do {
            // Get the hosted zone ID from stack outputs
            let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
            let awsClient = SotoCore.AWSClient(httpClient: httpClient)
            let cloudFormation = CloudFormation(
                client: awsClient,
                region: .useast1,
                endpoint: configuration.endpoint
            )

            let stacksResponse = try await cloudFormation.describeStacks(
                CloudFormation.DescribeStacksInput(stackName: stackName)
            )
            guard let stack = stacksResponse.stacks?.first,
                let outputs = stack.outputs
            else {
                Issue.record("Stack or outputs not found")
                return
            }

            let hostedZoneIdOutput = outputs.first { $0.outputKey == "HostedZoneId" }
            #expect(hostedZoneIdOutput != nil)

            guard let hostedZoneId = hostedZoneIdOutput?.outputValue else {
                Issue.record("HostedZoneId output not found")
                return
            }

            // Extract the zone ID
            let zoneId = hostedZoneId.split(separator: "/").last.map(String.init) ?? hostedZoneId

            // Verify only NS and SOA records exist (no MX, TXT, CNAME)
            let route53 = Route53(
                client: awsClient,
                endpoint: configuration.endpoint
            )
            let request = Route53.ListResourceRecordSetsRequest(
                hostedZoneId: zoneId
            )

            let response = try await route53.listResourceRecordSets(request)
            let records = response.resourceRecordSets

            // Should only have NS and SOA records
            let mxRecords = records.filter { $0.type == Route53.RRType.mx }
            #expect(mxRecords.isEmpty)

            let txtRecords = records.filter { $0.type == Route53.RRType.txt }
            #expect(txtRecords.isEmpty)

            let cnameRecords = records.filter { $0.type == Route53.RRType.cname }
            #expect(cnameRecords.isEmpty)

            // NS and SOA should exist
            let nsRecords = records.filter { $0.type == Route53.RRType.ns }
            #expect(!nsRecords.isEmpty)

            let soaRecords = records.filter { $0.type == Route53.RRType.soa }
            #expect(soaRecords.count == 1)

            print("✅ Minimal hosted zone verified successfully!")

            // Cleanup AWS clients
            try await awsClient.shutdown()
            try await httpClient.shutdown()

        } catch {
            Issue.record("Failed to create or verify minimal Route53 stack: \(error)")
            throw error
        }

        // Cleanup
        print("🧹 Cleaning up Route53 stack...")
        try await cfClient.deleteStack(stackName: stackName, region: .useast1)
    }
}
