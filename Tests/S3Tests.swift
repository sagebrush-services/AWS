import AsyncHTTPClient
import Foundation
import SotoCore
import SotoS3
import Testing

@testable import AWS

@Suite("S3 Bucket Tests")
struct S3Tests {
    @Test("Create S3 bucket with UUID name in LocalStack")
    func testCreateS3Bucket() async throws {
        let configuration = AWSConfiguration()
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)

        let awsClient = SotoCore.AWSClient(
            httpClient: httpClient
        )

        let s3 = S3(
            client: awsClient,
            region: .useast1,
            endpoint: configuration.endpoint
        )

        let bucketName = UUID().uuidString.lowercased()
        print("🪣 Creating S3 bucket: \(bucketName)")

        let createRequest = S3.CreateBucketRequest(
            bucket: bucketName
        )
        let createResponse = try await s3.createBucket(createRequest)

        #expect(createResponse.location != nil, "Bucket location should be returned")
        print("✅ Bucket created at: \(createResponse.location ?? "unknown")")

        print("🔍 Verifying bucket exists...")
        let listRequest = S3.ListBucketsRequest()
        let listResponse = try await s3.listBuckets(listRequest)

        guard let buckets = listResponse.buckets else {
            Issue.record("No buckets found")
            try await awsClient.shutdown()
            try await httpClient.shutdown()
            return
        }

        let createdBucket = buckets.first { $0.name == bucketName }
        #expect(createdBucket != nil, "Created bucket should exist in bucket list")
        print("✅ Bucket verified: \(bucketName)")

        print("🧹 Cleaning up bucket...")
        let deleteRequest = S3.DeleteBucketRequest(bucket: bucketName)
        try await s3.deleteBucket(deleteRequest)
        print("✅ Bucket deleted")

        try await awsClient.shutdown()
        try await httpClient.shutdown()
    }
}
