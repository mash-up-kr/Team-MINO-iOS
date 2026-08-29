// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProfileSetupUI",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ProfileSetupUI", targets: ["ProfileSetupUI"]),
    ],
    dependencies: [
        .package(path: "../MVI"),
        .package(path: "../DesignSystem"),
        .package(path: "../Domain"),
    ],
    targets: [
        .target(
            name: "ProfileSetupUI",
            dependencies: ["MVI", "DesignSystem", "Domain"]
        ),
        .testTarget(
            name: "ProfileSetupUITests",
            dependencies: [
                "ProfileSetupUI",
                .product(name: "MVITestSupport", package: "MVI"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
