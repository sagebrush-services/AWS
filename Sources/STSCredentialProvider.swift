import AsyncHTTPClient
import Foundation
import SotoCore
import SotoSTS

/// Provides temporary credentials by assuming an IAM role via STS
actor STSCredentialProvider {
    private let httpClient: HTTPClient
    private let configuration: AWSConfiguration

    init(httpClient: HTTPClient, configuration: AWSConfiguration) {
        self.httpClient = httpClient
        self.configuration = configuration
    }

    /// Assume an IAM role and return temporary credentials
    func assumeRole(
        account: Account,
        region: Region,
        sessionName: String? = nil
    ) async throws -> (accessKeyId: String, secretAccessKey: String, sessionToken: String) {
        // Create base AWS client with default credential chain (environment, config file, instance metadata, etc.)
        let baseClient = AWSClient(
            httpClient: httpClient
        )

        // Create STS client with proper endpoint
        let sts: STS
        if let endpoint = configuration.endpoint {
            sts = STS(client: baseClient, region: region, endpoint: endpoint)
        } else {
            sts = STS(client: baseClient, region: region)
        }

        // Generate session name if not provided
        let roleSessionName = sessionName ?? "sagebrush-cli-\(UUID().uuidString.prefix(8))"

        print("🔐 Assuming role in \(account.displayName) account (\(account.rawValue))...")
        print("   Role ARN: \(account.roleArn)")
        print("   Session: \(roleSessionName)")

        // Assume the role with ExternalId for security
        let request = STS.AssumeRoleRequest(
            externalId: "sagebrush-cli",
            roleArn: account.roleArn,
            roleSessionName: roleSessionName
        )

        let result: (accessKeyId: String, secretAccessKey: String, sessionToken: String)

        do {
            let response = try await sts.assumeRole(request)

            guard let credentials = response.credentials else {
                try await baseClient.shutdown()
                throw STSCredentialProviderError.missingCredentials
            }

            print("✅ Successfully assumed role in \(account.displayName) account")
            print("   Credentials expire at: \(credentials.expiration)")

            result = (
                accessKeyId: credentials.accessKeyId,
                secretAccessKey: credentials.secretAccessKey,
                sessionToken: credentials.sessionToken
            )

            try await baseClient.shutdown()
            return result
        } catch {
            print("❌ Failed to assume role: \(error)")
            try? await baseClient.shutdown()
            throw STSCredentialProviderError.assumeRoleFailed(error)
        }
    }
}

enum STSCredentialProviderError: Error, LocalizedError {
    case missingCredentials
    case assumeRoleFailed(Error)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "STS AssumeRole response did not contain credentials"
        case .assumeRoleFailed(let error):
            return "Failed to assume role: \(error.localizedDescription)"
        }
    }
}
