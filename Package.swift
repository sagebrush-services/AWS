// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AWS",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AWS", targets: ["AWS"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/soto-project/soto-core.git", from: "7.0.0"),
        .package(url: "https://github.com/soto-project/soto.git", from: "7.3.0"),
        .package(url: "https://github.com/apple/swift-configuration.git", from: "0.1.1"),
    ],
    targets: [
        .executableTarget(
            name: "AWS",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "SotoBudgets", package: "soto"),
                .product(name: "SotoCloudFormation", package: "soto"),
                .product(name: "SotoCodeBuild", package: "soto"),
                .product(name: "SotoCodeCommit", package: "soto"),
                .product(name: "SotoCore", package: "soto-core"),
                .product(name: "SotoEC2", package: "soto"),
                .product(name: "SotoECS", package: "soto"),
                .product(name: "SotoIAM", package: "soto"),
                .product(name: "SotoLambda", package: "soto"),
                .product(name: "SotoOrganizations", package: "soto"),
                .product(name: "SotoRDS", package: "soto"),
                .product(name: "SotoRoute53", package: "soto"),
                .product(name: "SotoS3", package: "soto"),
                .product(name: "SotoSecretsManager", package: "soto"),
                .product(name: "SotoSES", package: "soto"),
                .product(name: "SotoSTS", package: "soto"),
            ],
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "AWSTests",
            dependencies: [
                "AWS",
                .product(name: "SotoBudgets", package: "soto"),
                .product(name: "SotoCloudFormation", package: "soto"),
                .product(name: "SotoCloudWatchLogs", package: "soto"),
                .product(name: "SotoCodeBuild", package: "soto"),
                .product(name: "SotoCore", package: "soto-core"),
                .product(name: "SotoEC2", package: "soto"),
                .product(name: "SotoECS", package: "soto"),
                .product(name: "SotoElasticLoadBalancingV2", package: "soto"),
                .product(name: "SotoIAM", package: "soto"),
                .product(name: "SotoLambda", package: "soto"),
                .product(name: "SotoOrganizations", package: "soto"),
                .product(name: "SotoRDS", package: "soto"),
                .product(name: "SotoRoute53", package: "soto"),
                .product(name: "SotoS3", package: "soto"),
                .product(name: "SotoSecretsManager", package: "soto"),
                .product(name: "SotoSTS", package: "soto"),
            ],
            path: "Tests"
        ),
    ]
)
