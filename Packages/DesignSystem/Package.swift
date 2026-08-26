// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DesignSystem",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
    ],
    targets: [
        .target(
            name: "DesignSystem",
            resources: [
                .process("Resources/SemanticColor.xcassets"),
                .process("Resources/AtomicColor.xcassets"),
                .process("Resources/Icon.xcassets"),
                .process("Resources/Illustration.xcassets"),
                .process("Resources/Fonts"),
            ]
        ),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
    ],
    swiftLanguageModes: [.v6]
)
