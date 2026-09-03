// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlaceMapUI",
    // DesignSystem 이 iOS 전용이라 여기도 iOS 전용이다(PlaceDetailUI·RoomCreationUI 와 같다).
    // 이 패키지를 쓰는 Feature 의 reduce 테스트는 이미 시뮬레이터로 돈다.
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "PlaceMapUI", targets: ["PlaceMapUI"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../DesignSystem"),
        .package(path: "../MapUI"),
    ],
    targets: [
        .target(name: "PlaceMapUI", dependencies: ["Domain", "DesignSystem", "MapUI"]),
        .testTarget(name: "PlaceMapUITests", dependencies: ["PlaceMapUI", "Domain", "MapUI"]),
    ],
    swiftLanguageModes: [.v6]
)
