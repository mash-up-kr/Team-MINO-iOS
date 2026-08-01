// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureProfile",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FeatureProfile", targets: ["FeatureProfile"]),
    ],
    dependencies: [
        .package(path: "../FlowCoordination"),
    ],
    targets: [
        .target(name: "FeatureProfile", dependencies: ["FlowCoordination"]),
        .testTarget(name: "FeatureProfileTests", dependencies: ["FeatureProfile"]),
    ],
    swiftLanguageModes: [.v6]
)
