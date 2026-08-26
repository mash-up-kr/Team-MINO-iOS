// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlowCoordination",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FlowCoordination", targets: ["FlowCoordination"]),
    ],
    targets: [
        .target(name: "FlowCoordination"),
        .testTarget(name: "FlowCoordinationTests", dependencies: ["FlowCoordination"]),
    ],
    swiftLanguageModes: [.v6]
)
