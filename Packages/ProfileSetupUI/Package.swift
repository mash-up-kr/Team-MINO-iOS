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
    ],
    targets: [
        .target(
            name: "ProfileSetupUI",
            dependencies: ["MVI", "DesignSystem"]
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
