import Configuration
import Foundation

/// Configuration for AWS client
struct AWSConfiguration {
    /// Whether running in production environment
    let isProduction: Bool

    /// Custom endpoint URL for AWS services (LocalStack in development)
    var endpoint: String? {
        isProduction ? nil : "http://localhost.localstack.cloud:4566"
    }

    init() {
        // Check ENV environment variable
        let env = ProcessInfo.processInfo.environment["ENV"]
        self.isProduction = env?.lowercased() == "production"
    }
}
