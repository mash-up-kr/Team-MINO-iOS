// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MapUI",
    // macOS 도 선언: Feature 의 reduce 테스트가 macOS 호스트에서 도는데,
    // Feature 가 MapUI 의 순수 value type 을 참조하므로 MapUI 도 macOS 빌드가 돼야 한다.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MapUI", targets: ["MapUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/googlemaps/ios-maps-sdk", from: "10.15.0"),
    ],
    targets: [
        .target(
            name: "MapUI",
            dependencies: [
                // GoogleMaps 는 iOS 전용 바이너리 → iOS 에서만 링크한다.
                // macOS(테스트 호스트) 빌드에는 포함되지 않아 순수 타입만 컴파일된다.
                .product(name: "GoogleMaps", package: "ios-maps-sdk", condition: .when(platforms: [.iOS])),
            ]
        ),
        // 순수 타입은 로직이 없고 브릿지(MapView)는 UIViewRepresentable 이라 단위 테스트 대상이 아니다.
        // 지도 이벤트→화면 전환 로직은 Feature 의 MapHomeReducerTests 가 검증한다.
    ],
    swiftLanguageModes: [.v6]
)
