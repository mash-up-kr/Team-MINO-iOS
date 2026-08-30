// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureHome",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FeatureHome", targets: ["FeatureHome"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../DesignSystem"),
        .package(path: "../FlowCoordination"),
        .package(path: "../MVI"),
        .package(path: "../RoomCreationUI"),
        .package(path: "../PlaceDetailUI"),
        .package(path: "../ProfileSetupUI"),
    ],
    targets: [
        .target(name: "FeatureHome", dependencies: ["Domain", "DesignSystem", "FlowCoordination", "MVI", "RoomCreationUI", "PlaceDetailUI", "ProfileSetupUI"]),
        .testTarget(
            name: "FeatureHomeTests",
            dependencies: [
                "FeatureHome",
                .product(name: "MVITestSupport", package: "MVI"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
