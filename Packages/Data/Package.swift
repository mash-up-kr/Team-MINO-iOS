// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Data",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Data", targets: ["Data"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../Networking"),
    ],
    targets: [
        .target(name: "Data", dependencies: ["Domain", "Networking"]),
        .testTarget(name: "DataTests", dependencies: ["Data", "Networking"]),
    ],
    swiftLanguageModes: [.v6]
)
