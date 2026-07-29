#if canImport(GoogleMaps)
import GoogleMaps
#endif
import os

/// GoogleMaps SDK 초기화 진입점. App(Composition Root)에서 앱 시작 시 1회 호출한다.
/// `GMSServices.provideAPIKey` 호출을 MapUI 안에 가두어 App 이 GoogleMaps 를 직접 import 하지 않게 한다.
public enum MapService {
    /// SDK 초기화 성공 여부. 키 미설정 상태로 `GMSMapView` 를 만들면 SDK 가 예외를 던져 크래시하므로,
    /// 화면 쪽은 이 값으로 지도 렌더 여부를 가드한다(false 면 안내 placeholder 표시).
    @MainActor public private(set) static var isConfigured = false

    /// API 키로 SDK 를 초기화한다. 키가 비어 있으면(미발급) 호출을 건너뛴다 —
    /// `provideAPIKey("")` 는 크래시를 유발한다. 이때 `isConfigured` 가 false 로 남아 지도 렌더가 가드된다.
    @MainActor public static func configure(apiKey: String) {
        guard !apiKey.isEmpty else {
            // 앱 Logging 모듈에 의존하지 않도록 시스템 os.Logger 사용 (MapUI 는 인프라 패키지)
            Logger(subsystem: "MapUI", category: "MapService")
                .warning("GoogleMaps API 키 미설정 — 지도 화면은 안내 placeholder 로 대체된다 (App/Config/Secrets.xcconfig)")
            return
        }
        #if canImport(GoogleMaps)
        GMSServices.provideAPIKey(apiKey)
        isConfigured = true
        #endif
    }
}
