// swift-tools-version: 6.0
import PackageDescription

// 공통 UI 레이어(`*UI`) — Share Extension 이 가져다 쓰고, 자기는 어떤 Feature 도 모른다.
// 허용 의존 목록은 .claude/docs/mvi-coordinator-di.md 1절 「허용 의존」 참조.
// SavePostUI 는 홈과 함께 쓰는 게시물 저장 시트(와 그 표시용 값 SavePostRoom)를 위해 쓴다.
let package = Package(
    name: "ShareExtensionUI",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ShareExtensionUI", targets: ["ShareExtensionUI"]),
    ],
    dependencies: [
        .package(path: "../MVI"),
        .package(path: "../DesignSystem"),
        .package(path: "../SavePostUI"),
    ],
    targets: [
        .target(
            name: "ShareExtensionUI",
            dependencies: ["MVI", "DesignSystem", "SavePostUI"]
        ),
        .testTarget(
            name: "ShareExtensionUITests",
            dependencies: [
                "ShareExtensionUI",
                .product(name: "MVITestSupport", package: "MVI"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
