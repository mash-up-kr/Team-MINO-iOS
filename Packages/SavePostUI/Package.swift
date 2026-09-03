// swift-tools-version: 6.0
import PackageDescription

// 공통 UI 레이어(`*UI`) — 게시물 저장 바텀시트(Figma 013-1-3)를 홈(FeatureHome)과
// 공유 익스텐션(ShareExtensionUI)이 함께 쓴다. 상태를 들지 않는 표현 전용이라 MVI 의존이 없다.
// 허용 의존 목록은 .claude/docs/mvi-coordinator-di.md 1절 「허용 의존」 참조.
let package = Package(
    name: "SavePostUI",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SavePostUI", targets: ["SavePostUI"]),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(name: "SavePostUI", dependencies: ["DesignSystem"]),
        .testTarget(name: "SavePostUITests", dependencies: ["SavePostUI"]),
    ],
    swiftLanguageModes: [.v6]
)
