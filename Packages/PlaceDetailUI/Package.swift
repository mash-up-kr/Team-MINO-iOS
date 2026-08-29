// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlaceDetailUI",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "PlaceDetailUI", targets: ["PlaceDetailUI"]),
    ],
    dependencies: [
        .package(path: "../MVI"),
        .package(path: "../DesignSystem"),
        .package(path: "../Domain"),
        .package(path: "../ProfileSetupUI"),
    ],
    targets: [
        .target(
            name: "PlaceDetailUI",
            dependencies: ["MVI", "DesignSystem", "Domain", "ProfileSetupUI"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PlaceDetailUITests",
            dependencies: [
                "PlaceDetailUI",
                "Domain",
                .product(name: "MVITestSupport", package: "MVI"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
