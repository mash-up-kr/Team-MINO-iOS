// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeatureRoomCreation",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureRoomCreation", targets: ["FeatureRoomCreation"]),
    ],
    dependencies: [
        .package(path: "../MVI"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(
            name: "FeatureRoomCreation",
            dependencies: ["MVI", "DesignSystem"]
        ),
        .testTarget(
            name: "FeatureRoomCreationTests",
            dependencies: [
                "FeatureRoomCreation",
                .product(name: "MVITestSupport", package: "MVI"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
