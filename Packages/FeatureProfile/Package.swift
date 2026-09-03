// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureProfile",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureProfile", targets: ["FeatureProfile"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../FlowCoordination"),
        .package(path: "../MVI"),
        .package(path: "../DesignSystem"),
        .package(path: "../ProfileSetupUI"),
    ],
    targets: [
        .target(
            name: "FeatureProfile",
            dependencies: ["Domain", "FlowCoordination", "MVI", "DesignSystem", "ProfileSetupUI"]
        ),
        .testTarget(
            name: "FeatureProfileTests",
            dependencies: [
                "FeatureProfile",
                .product(name: "MVITestSupport", package: "MVI"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
