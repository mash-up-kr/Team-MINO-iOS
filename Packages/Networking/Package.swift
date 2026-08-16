// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Networking",
    // 앱은 iOS 전용이지만, 호스트 `swift test` 검증을 위해 macOS 플로어도 선언한다.
    // (의존하는 Logging 이 macOS 13+ 를 요구)
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "Networking", targets: ["Networking"]),
    ],
    dependencies: [
        .package(path: "../Logging"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.12.0")),
    ],
    targets: [
        .target(
            name: "Networking",
            dependencies: [
                "Logging",
                .product(name: "Alamofire", package: "Alamofire"),
            ]
        ),
        .testTarget(name: "NetworkingTests", dependencies: ["Networking"]),
    ],
    swiftLanguageModes: [.v6]
)
