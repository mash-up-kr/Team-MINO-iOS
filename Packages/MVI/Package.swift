// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MVI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MVI", targets: ["MVI"]),
        .library(name: "MVITestSupport", targets: ["MVITestSupport"]),
    ],
    targets: [
        .target(name: "MVI"),
        .target(name: "MVITestSupport", dependencies: ["MVI"]),
        .testTarget(name: "MVITests", dependencies: ["MVI", "MVITestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
