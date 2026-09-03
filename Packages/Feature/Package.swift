// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Feature",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Feature", targets: ["Feature"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../FlowCoordination"),
        .package(path: "../MVI"),
    ],
    targets: [
        .target(name: "Feature", dependencies: ["Domain", "FlowCoordination", "MVI"]),
        .testTarget(
            name: "FeatureTests",
            dependencies: [
                "Feature",
                .product(name: "MVITestSupport", package: "MVI"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
