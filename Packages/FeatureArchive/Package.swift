// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureArchive",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FeatureArchive", targets: ["FeatureArchive"]),
    ],
    dependencies: [
        .package(path: "../FlowCoordination"),
        .package(path: "../DesignSystem"),
        .package(path: "../MVI"),
        .package(path: "../Domain"),
    ],
    targets: [
        .target(
            name: "FeatureArchive",
            dependencies: ["FlowCoordination", "DesignSystem", "MVI", "Domain"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "FeatureArchiveTests",
            dependencies: [
                "FeatureArchive",
                "Domain",
                .product(name: "MVITestSupport", package: "MVI"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
