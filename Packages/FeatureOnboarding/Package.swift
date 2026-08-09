// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureOnboarding",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureOnboarding", targets: ["FeatureOnboarding"]),
    ],
    dependencies: [
        .package(path: "../FlowCoordination"),
        .package(path: "../MVI"),
        .package(path: "../DesignSystem"),
        .package(path: "../RoomCreationUI"),
    ],
    targets: [
        .target(
            name: "FeatureOnboarding",
            dependencies: ["FlowCoordination", "MVI", "DesignSystem", "RoomCreationUI"]
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
