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
        .package(path: "../PlaceMapUI"),
        .package(path: "../RoomShareUI"),
        .package(path: "../ProfileSetupUI"),
        .package(path: "../PlaceDetailUI"),
    ],
    targets: [
        .target(
            name: "FeatureArchive",
            dependencies: ["FlowCoordination", "DesignSystem", "MVI", "Domain", "Core", "RoomCreationUI", "PlaceMapUI", "RoomShareUI", "ProfileSetupUI", "PlaceDetailUI"]
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
