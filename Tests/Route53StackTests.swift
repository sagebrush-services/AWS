import Foundation
import Testing

@testable import AWS

@Suite("Route53Stack")
struct Route53StackTests {
    @Test("Route53Stack has valid CloudFormation template")
    func testRoute53StackTemplate() {
        let stack = Route53Stack()
        #expect(!stack.templateBody.isEmpty)
        #expect(stack.templateBody.contains("AWS::Route53::HostedZone"))
        #expect(stack.templateBody.contains("AWS::Route53::RecordSet"))
    }

    @Test("Route53Stack template is valid JSON")
    func testRoute53StackJSON() throws {
        let stack = Route53Stack()
        let data = Data(stack.templateBody.utf8)
        let json = try JSONSerialization.jsonObject(with: data)
        #expect(json is [String: Any])
    }

    @Test("Route53Stack has required parameters")
    func testRoute53StackParameters() {
        let stack = Route53Stack()
        #expect(stack.templateBody.contains("\"DomainName\""))
        #expect(stack.templateBody.contains("\"HostedZoneComment\""))
        #expect(stack.templateBody.contains("\"WWWRecordTarget\""))
        #expect(stack.templateBody.contains("\"StagingRecordTarget\""))
        #expect(stack.templateBody.contains("\"MXRecordValue\""))
        #expect(stack.templateBody.contains("\"SPFRecord\""))
        #expect(stack.templateBody.contains("\"DMARCRecord\""))
        #expect(stack.templateBody.contains("\"DKIMToken1\""))
        #expect(stack.templateBody.contains("\"DKIMValue1\""))
    }

    @Test("Route53Stack exports required outputs")
    func testRoute53StackOutputs() {
        let stack = Route53Stack()
        #expect(stack.templateBody.contains("HostedZoneId"))
        #expect(stack.templateBody.contains("NameServers"))
        #expect(stack.templateBody.contains("DomainName"))
    }

    @Test("Route53Stack has conditional DNS records")
    func testRoute53StackConditionalRecords() {
        let stack = Route53Stack()
        #expect(stack.templateBody.contains("\"Conditions\""))
        #expect(stack.templateBody.contains("CreateWWWRecord"))
        #expect(stack.templateBody.contains("CreateStagingRecord"))
        #expect(stack.templateBody.contains("CreateMXRecord"))
        #expect(stack.templateBody.contains("CreateSPFRecord"))
        #expect(stack.templateBody.contains("CreateDMARCRecord"))
        #expect(stack.templateBody.contains("CreateDKIM1"))
        #expect(stack.templateBody.contains("CreateDKIM2"))
        #expect(stack.templateBody.contains("CreateDKIM3"))
    }

    @Test("Route53Stack has WWW and Staging CNAME records")
    func testRoute53StackCNAMERecords() {
        let stack = Route53Stack()
        #expect(stack.templateBody.contains("WWWARecord"))
        #expect(stack.templateBody.contains("StagingARecord"))
        #expect(stack.templateBody.contains("\"Type\": \"CNAME\""))
    }

    @Test("Route53Stack has email records (MX, SPF, DMARC)")
    func testRoute53StackEmailRecords() {
        let stack = Route53Stack()
        #expect(stack.templateBody.contains("MXRecord"))
        #expect(stack.templateBody.contains("SPFRecord"))
        #expect(stack.templateBody.contains("DMARCRecord"))
        #expect(stack.templateBody.contains("\"Type\": \"MX\""))
        #expect(stack.templateBody.contains("\"Type\": \"TXT\""))
        #expect(stack.templateBody.contains("_dmarc"))
    }

    @Test("Route53Stack has DKIM CNAME records")
    func testRoute53StackDKIMRecords() {
        let stack = Route53Stack()
        #expect(stack.templateBody.contains("DKIM1CNAMERecord"))
        #expect(stack.templateBody.contains("DKIM2CNAMERecord"))
        #expect(stack.templateBody.contains("DKIM3CNAMERecord"))
        #expect(stack.templateBody.contains("_domainkey"))
    }
}
