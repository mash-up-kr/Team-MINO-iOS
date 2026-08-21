// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureProfile",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FeatureProfile", targets: ["FeatureProfile"]),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
        .package(path: "../FlowCoordination"),
        .package(path: "../MVI"),
        .package(path: "../RoomCreationUI"),
    ],
    targets: [
        .target(name: "FeatureProfile", dependencies: ["DesignSystem", "FlowCoordination", "MVI", "RoomCreationUI"]),
        .testTarget(name: "FeatureProfileTests", dependencies: ["FeatureProfile"]),
    ],
    swiftLanguageModes: [.v6]
)
