// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RoomShareUI",
    // DesignSystem 이 iOS 전용이라 여기도 iOS 전용이다(PlaceDetailUI·PlaceMapUI 와 같다).
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "RoomShareUI", targets: ["RoomShareUI"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../DesignSystem"),
        .package(path: "../MVI"),
    ],
    targets: [
        // FlowCoordination 에 의존하지 않는다 — 시트 위에 덮는 「공동방 만들기」 flow 는
        // 띄우는 Feature 가 소유하고, 시트는 그 화면을 클로저로 받는다(*UI 규칙).
        .target(name: "RoomShareUI", dependencies: ["Domain", "DesignSystem", "MVI"]),
        .testTarget(
            name: "RoomShareUITests",
            dependencies: ["RoomShareUI", "Domain", .product(name: "MVITestSupport", package: "MVI")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
