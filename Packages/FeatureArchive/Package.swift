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
        .package(path: "../MVI"),
        .package(path: "../Domain"),
        .package(path: "../Core"),
        .package(path: "../RoomCreationUI"),
        .package(path: "../MapUI"),
        .package(path: "../ProfileSetupUI"),
    ],
    targets: [
        .target(
            name: "FeatureArchive",
            dependencies: ["FlowCoordination", "DesignSystem", "MVI", "Domain", "Core", "RoomCreationUI", "MapUI", "ProfileSetupUI"],
            // develop 이 emptyCommentIllustration 을 이 카탈로그에 넣었다 — 내 쪽에서 지웠던 선언을 되살린다.
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "FeatureArchiveTests",
            dependencies: [
                "FeatureArchive",
                "Domain",
                "Core",
                .product(name: "MVITestSupport", package: "MVI"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
