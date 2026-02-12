import AsyncHTTPClient
import Foundation
import SotoCloudFormation
import SotoCore

/// CloudFormation client wrapper for managing stacks
actor CloudFormationClient {
    let client: SotoCore.AWSClient
    let configuration: AWSConfiguration
    let httpClient: HTTPClient

    init(profile: String? = nil, configuration: AWSConfiguration = AWSConfiguration()) {
        self.configuration = configuration
        self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton)

        // Log environment
        if configuration.endpoint != nil {
            print("🔧 Using LocalStack endpoint: http://localhost.localstack.cloud:4566")
        } else {
            print("☁️  Using production AWS endpoints")
        }

        // Use provided profile or default
        if let profile = profile {
            self.client = SotoCore.AWSClient(
                credentialProvider: .configFile(profile: profile),
                httpClient: httpClient
            )
        } else {
            self.client = SotoCore.AWSClient(
                httpClient: httpClient
            )
        }
    }

    /// Initialize with account-based authentication using STS AssumeRole
    init(account: Account, region: Region, configuration: AWSConfiguration = AWSConfiguration()) async throws {
        self.configuration = configuration
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        self.httpClient = httpClient

        // Log environment
        if configuration.endpoint != nil {
            print("🔧 Using LocalStack endpoint: http://localhost.localstack.cloud:4566")
        } else {
            print("☁️  Using production AWS endpoints")
        }

        // Use STS to assume role in target account
        let stsProvider = STSCredentialProvider(
            httpClient: httpClient,
            configuration: configuration
        )

        do {
            let credentials = try await stsProvider.assumeRole(
                account: account,
                region: region
            )

            // Create client with assumed role credentials
            self.client = SotoCore.AWSClient(
                credentialProvider: .static(
                    accessKeyId: credentials.accessKeyId,
                    secretAccessKey: credentials.secretAccessKey,
                    sessionToken: credentials.sessionToken
                ),
                httpClient: httpClient
            )
        } catch {
            // Clean up httpClient if assumeRole fails
            try? await httpClient.shutdown()
            throw error
        }
    }

    /// Create a CloudFormation service client with proper endpoint
    private func createCloudFormation(region: Region) -> CloudFormation {
        if let endpoint = configuration.endpoint {
            return CloudFormation(client: client, region: region, endpoint: endpoint)
        } else {
            return CloudFormation(client: client, region: region)
        }
    }

    /// Create or update a CloudFormation stack
    func upsertStack(
        stack: Stack,
        region: Region,
        stackName: String,
        parameters: [String: String] = [:]
    ) async throws {
        let cloudFormation = createCloudFormation(region: region)

        // Convert parameters to CloudFormation format
        let cfParameters = parameters.map { key, value in
            CloudFormation.Parameter(parameterKey: key, parameterValue: value)
        }

        // Check if stack exists and get its status
        let describeRequest = CloudFormation.DescribeStacksInput(stackName: stackName)

        do {
            let response = try await cloudFormation.describeStacks(describeRequest)

            // Check stack status
            if let existingStack = response.stacks?.first, let status = existingStack.stackStatus {
                // If stack is in a failed state, delete it first
                if status == .rollbackComplete || status == .rollbackFailed || status == .createFailed
                    || status == .deleteComplete
                {
                    print("⚠️  Stack is in state \(status.rawValue), deleting...")
                    let deleteRequest = CloudFormation.DeleteStackInput(stackName: stackName)
                    _ = try await cloudFormation.deleteStack(deleteRequest)

                    // Wait for deletion
                    try await waitForStackDeletion(stackName: stackName, region: region)

                    // Now create new stack
                    print("🆕 Creating new stack: \(stackName)")
                    let createRequest = CloudFormation.CreateStackInput(
                        capabilities: [.capabilityIam, .capabilityNamedIam],
                        parameters: cfParameters.isEmpty ? nil : cfParameters,
                        stackName: stackName,
                        templateBody: stack.templateBody
                    )

                    _ = try await cloudFormation.createStack(createRequest)
                    print("✅ Stack creation initiated: \(stackName)")
                } else {
                    // Stack exists and is in a good state, update it
                    print("📝 Updating existing stack: \(stackName)")
                    let updateRequest = CloudFormation.UpdateStackInput(
                        capabilities: [.capabilityIam, .capabilityNamedIam],
                        parameters: cfParameters.isEmpty ? nil : cfParameters,
                        stackName: stackName,
                        templateBody: stack.templateBody
                    )

                    _ = try await cloudFormation.updateStack(updateRequest)
                    print("✅ Stack update initiated: \(stackName)")
                }
            }
        } catch {
            // Stack doesn't exist, create it
            print("🆕 Creating new stack: \(stackName)")
            let createRequest = CloudFormation.CreateStackInput(
                capabilities: [.capabilityIam, .capabilityNamedIam],
                parameters: cfParameters.isEmpty ? nil : cfParameters,
                stackName: stackName,
                templateBody: stack.templateBody
            )

            _ = try await cloudFormation.createStack(createRequest)
            print("✅ Stack creation initiated: \(stackName)")
        }

        // Wait for stack operation to complete
        try await waitForStackCompletion(stackName: stackName, region: region)
    }

    /// Wait for stack deletion to complete
    private func waitForStackDeletion(stackName: String, region: Region) async throws {
        let cloudFormation = createCloudFormation(region: region)
        let maxAttempts = 180  // 15 minutes for Aurora deletion
        var attempts = 0

        while attempts < maxAttempts {
            let describeRequest = CloudFormation.DescribeStacksInput(stackName: stackName)

            do {
                let response = try await cloudFormation.describeStacks(describeRequest)

                guard let stack = response.stacks?.first,
                    let status = stack.stackStatus
                else {
                    // Stack no longer exists
                    print("✅ Stack deleted: \(stackName)")
                    return
                }

                if status == .deleteFailed {
                    // Print error events before throwing
                    try await printStackErrors(stackName: stackName, region: region)
                    throw AWSClientError.stackOperationFailed(stackName, "DELETE_FAILED")
                }

                print("⏳ Deletion status: \(status.rawValue)")
                try await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
                attempts += 1
            } catch {
                // Stack not found means it's deleted
                if error.localizedDescription.contains("does not exist") {
                    print("✅ Stack deleted: \(stackName)")
                    return
                }
                throw error
            }
        }

        throw AWSClientError.timeout(stackName)
    }

    /// Print CloudFormation stack errors
    private func printStackErrors(stackName: String, region: Region) async throws {
        let cloudFormation = createCloudFormation(region: region)
        let eventsRequest = CloudFormation.DescribeStackEventsInput(stackName: stackName)

        do {
            let eventsResponse = try await cloudFormation.describeStackEvents(eventsRequest)

            print("\n❌ Stack operation failed. Error events:")
            print("==========================================")

            if let events = eventsResponse.stackEvents {
                let failedEvents = events.filter { event in
                    if let status = event.resourceStatus {
                        return status == .createFailed || status == .updateFailed || status == .deleteFailed
                    }
                    return false
                }

                for event in failedEvents {
                    if let resourceId = event.logicalResourceId,
                       let reason = event.resourceStatusReason {
                        print("  🔴 \(resourceId):")
                        print("     \(reason)")
                    }
                }
            }

            print("==========================================\n")
        } catch {
            // Ignore errors fetching events - the stack might already be deleted
            print("⚠️  Could not fetch stack events (stack may be deleted)")
        }
    }

    /// Wait for stack operation to complete
    private func waitForStackCompletion(stackName: String, region: Region) async throws {
        let cloudFormation = createCloudFormation(region: region)
        let maxAttempts = 180  // 15 minutes for Aurora creation
        var attempts = 0

        while attempts < maxAttempts {
            let describeRequest = CloudFormation.DescribeStacksInput(stackName: stackName)
            let response = try await cloudFormation.describeStacks(describeRequest)

            guard let stack = response.stacks?.first else {
                throw AWSClientError.stackNotFound(stackName)
            }

            guard let status = stack.stackStatus else {
                throw AWSClientError.stackNotFound(stackName)
            }

            switch status {
            case .createComplete, .updateComplete:
                print("✅ Stack operation completed: \(stackName)")
                return
            case .createFailed, .updateFailed, .rollbackComplete, .rollbackFailed, .updateRollbackComplete,
                .updateRollbackFailed:
                // Print error events before throwing
                try await printStackErrors(stackName: stackName, region: region)
                throw AWSClientError.stackOperationFailed(stackName, status.rawValue)
            default:
                print("⏳ Stack status: \(status.rawValue)")
                try await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
                attempts += 1
            }
        }

        throw AWSClientError.timeout(stackName)
    }

    /// Delete a CloudFormation stack
    func deleteStack(stackName: String, region: Region) async throws {
        let cloudFormation = createCloudFormation(region: region)

        print("🗑️  Deleting stack: \(stackName)")
        let deleteRequest = CloudFormation.DeleteStackInput(stackName: stackName)
        _ = try await cloudFormation.deleteStack(deleteRequest)

        // Wait for deletion to complete
        try await waitForStackDeletion(stackName: stackName, region: region)
    }

    /// Shut down the AWS client and HTTP client
    func shutdown() async throws {
        try await client.shutdown()
        try await httpClient.shutdown()
    }
}

enum AWSClientError: Error, LocalizedError {
    case stackNotFound(String)
    case stackOperationFailed(String, String)
    case timeout(String)

    var errorDescription: String? {
        switch self {
        case .stackNotFound(let name):
            return "Stack not found: \(name)"
        case .stackOperationFailed(let name, let status):
            return "Stack operation failed for \(name): \(status)"
        case .timeout(let name):
            return "Timeout waiting for stack operation to complete: \(name)"
        }
    }
}
