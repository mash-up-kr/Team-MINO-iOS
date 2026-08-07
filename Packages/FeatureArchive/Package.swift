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
    ],
    targets: [
        .target(name: "FeatureArchive", dependencies: ["FlowCoordination", "DesignSystem"]),
        .testTarget(name: "FeatureArchiveTests", dependencies: ["FeatureArchive"]),
    ],
    swiftLanguageModes: [.v6]
)
