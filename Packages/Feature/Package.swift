// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Feature",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Feature", targets: ["Feature"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(name: "Feature", dependencies: ["Domain", "DesignSystem"]),
        .testTarget(name: "FeatureTests", dependencies: ["Feature"]),
    ],
    swiftLanguageModes: [.v6]
)
