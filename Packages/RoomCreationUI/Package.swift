// swift-tools-version: 6.0
import PackageDescription

// 공통 UI 레이어(`*UI`) — 여러 Feature 가 가져다 쓰고, 자기는 어떤 Feature 도 모른다.
// 허용 의존 목록은 .claude/docs/mvi-coordinator-di.md 1절 「허용 의존」 참조.
// 역방향 의존은 선언만 하면 컴파일되므로 빌드가 잡지 못한다 — 지금은 리뷰가 유일한 게이트다.
let package = Package(
    name: "RoomCreationUI",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "RoomCreationUI", targets: ["RoomCreationUI"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../MVI"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(
            name: "RoomCreationUI",
            dependencies: ["Domain", "MVI", "DesignSystem"]
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
