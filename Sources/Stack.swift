import Foundation

/// A CloudFormation stack template
protocol Stack {
    /// The CloudFormation template body as JSON
    var templateBody: String { get }
}
