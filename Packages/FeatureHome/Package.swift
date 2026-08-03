// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureHome",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FeatureHome", targets: ["FeatureHome"]),
    ],
    dependencies: [
        .package(path: "../FlowCoordination"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(name: "FeatureHome", dependencies: ["FlowCoordination", "DesignSystem"]),
        .testTarget(name: "FeatureHomeTests", dependencies: ["FeatureHome"]),
    ],
    swiftLanguageModes: [.v6]
)
