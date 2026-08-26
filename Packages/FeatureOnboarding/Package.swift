// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureOnboarding",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureOnboarding", targets: ["FeatureOnboarding"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../FlowCoordination"),
        .package(path: "../MVI"),
        .package(path: "../DesignSystem"),
        .package(path: "../Domain"),
        .package(path: "../RoomCreationUI"),
        .package(path: "../ProfileSetupUI"),
    ],
    targets: [
        .target(
            name: "FeatureOnboarding",
            dependencies: ["Core", "FlowCoordination", "MVI", "DesignSystem", "Domain", "RoomCreationUI", "ProfileSetupUI"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "FeatureOnboardingTests",
            dependencies: [
                "FeatureOnboarding",
                .product(name: "MVITestSupport", package: "MVI"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
