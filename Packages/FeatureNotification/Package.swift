// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureNotification",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureNotification", targets: ["FeatureNotification"]),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
        .package(path: "../Domain"),
        .package(path: "../FlowCoordination"),
        .package(path: "../MVI"),
    ],
    targets: [
        .target(
            name: "FeatureNotification",
            dependencies: ["DesignSystem", "Domain", "FlowCoordination", "MVI"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "FeatureNotificationTests",
            dependencies: [
                "FeatureNotification",
                "DesignSystem",
                "Domain",
                .product(name: "MVITestSupport", package: "MVI"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
