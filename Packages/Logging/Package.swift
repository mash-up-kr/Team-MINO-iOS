// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Logging",
    // 앱은 iOS 전용이지만, 호스트 `swift test` 검증을 위해 macOS 플로어도 선언한다.
    // (os.Logger privacy 보간·OSAllocatedUnfairLock 이 macOS 13+ 를 요구)
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "Logging", targets: ["Logging"]),
    ],
    targets: [
        .target(name: "Logging"),
        .testTarget(name: "LoggingTests", dependencies: ["Logging"]),
    ],
    swiftLanguageModes: [.v6]
)
