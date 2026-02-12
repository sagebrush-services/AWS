import Foundation
import Testing

@testable import AWS

@Suite("SESStack")
struct SESStackTests {
    @Test("SESStack has valid CloudFormation template")
    func testSESStackTemplate() {
        let stack = SESStack()
        #expect(!stack.templateBody.isEmpty)
        #expect(stack.templateBody.contains("AWS::SES::EmailIdentity"))
        #expect(stack.templateBody.contains("DkimSigningAttributes"))
        #expect(stack.templateBody.contains("SigningEnabled"))
    }

    @Test("SESStack template is valid JSON")
    func testSESStackJSON() throws {
        let stack = SESStack()
        let data = Data(stack.templateBody.utf8)
        let json = try JSONSerialization.jsonObject(with: data)
        #expect(json is [String: Any])
    }

    @Test("SESStack has required parameters")
    func testSESStackParameters() {
        let stack = SESStack()
        #expect(stack.templateBody.contains("\"DomainName\""))
        #expect(stack.templateBody.contains("\"EmailAddress\""))
        #expect(stack.templateBody.contains("sagebrush.services"))
        #expect(stack.templateBody.contains("support@sagebrush.services"))
    }

    @Test("SESStack exports required outputs")
    func testSESStackOutputs() {
        let stack = SESStack()
        #expect(stack.templateBody.contains("DomainIdentityArn"))
        #expect(stack.templateBody.contains("EmailIdentityArn"))
        #expect(stack.templateBody.contains("DKIMToken1"))
        #expect(stack.templateBody.contains("DKIMToken2"))
        #expect(stack.templateBody.contains("DKIMToken3"))
        #expect(stack.templateBody.contains("DKIMValue1"))
        #expect(stack.templateBody.contains("DKIMValue2"))
        #expect(stack.templateBody.contains("DKIMValue3"))
    }

    @Test("SESStack has DKIM configuration")
    func testSESStackDKIM() {
        let stack = SESStack()
        #expect(stack.templateBody.contains("DkimSigningAttributes"))
        #expect(stack.templateBody.contains("RSA_2048_BIT"))
        #expect(stack.templateBody.contains("DkimAttributes"))
        #expect(stack.templateBody.contains("SigningEnabled"))
    }
}
