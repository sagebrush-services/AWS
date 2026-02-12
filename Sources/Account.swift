import ArgumentParser
import Foundation

/// AWS accounts in the Sagebrush organization
enum Account: String, CaseIterable, ExpressibleByArgument {
    case management = "731099197338"
    case production = "978489150794"
    case staging = "889786867297"
    case housekeeping = "374073887345"
    case neonlaw = "102186460229"

    /// The IAM role ARN to assume in this account
    var roleArn: String {
        "arn:aws:iam::\(rawValue):role/SagebrushCLIRole"
    }

    /// Human-readable account name
    var displayName: String {
        switch self {
        case .management: return "Management"
        case .production: return "Production"
        case .staging: return "Staging"
        case .housekeeping: return "Housekeeping"
        case .neonlaw: return "NeonLaw"
        }
    }

    /// Account email address
    var email: String {
        switch self {
        case .management: return "sagebrush@shook.family"
        case .production: return "sagebrush-prod@shook.family"
        case .staging: return "sagebrush-staging@shook.family"
        case .housekeeping: return "sagebrush-housekeeping@shook.family"
        case .neonlaw: return "neon-law@shook.family"
        }
    }
}
