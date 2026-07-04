#if canImport(GoogleMaps)
import GoogleMaps
#endif

/// GoogleMaps SDK 초기화 진입점. App(Composition Root)에서 앱 시작 시 1회 호출한다.
/// `GMSServices.provideAPIKey` 호출을 MapUI 안에 가두어 App 이 GoogleMaps 를 직접 import 하지 않게 한다.
public enum MapService {
    /// API 키로 SDK 를 초기화한다. 키가 비어 있으면(미발급) 호출을 건너뛴다 —
    /// `provideAPIKey("")` 는 크래시를 유발하므로, 키 없이도 앱은 뜨고 지도만 회색으로 표시된다.
    public static func configure(apiKey: String) {
        guard !apiKey.isEmpty else { return }
        #if canImport(GoogleMaps)
        GMSServices.provideAPIKey(apiKey)
        #endif
    }
}
