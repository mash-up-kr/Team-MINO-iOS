// swift-tools-version: 6.0
import PackageDescription

// 공통 화면 레이어(`*UI`) — 여러 Feature 가 가져다 쓰고, 자기는 어떤 Feature 도 모른다.
// Feature 의존을 추가하면 CI(layer-guard)가 막는다.
let package = Package(
    name: "RoomCreationUI",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "RoomCreationUI", targets: ["RoomCreationUI"]),
    ],
    dependencies: [
        .package(path: "../MVI"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(
            name: "RoomCreationUI",
            dependencies: ["MVI", "DesignSystem"]
        ),
        .testTarget(
            name: "RoomCreationUITests",
            dependencies: [
                "RoomCreationUI",
                .product(name: "MVITestSupport", package: "MVI"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
