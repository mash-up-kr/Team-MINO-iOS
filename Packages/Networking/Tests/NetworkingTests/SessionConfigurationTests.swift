import Alamofire
import Foundation
import Testing
@testable import Networking

/// `Session.mino()` 는 프로덕션 클라이언트가 쓰는 유일한 세션인데, 여기 담긴 값들이
/// 회귀해도 다른 테스트는 전부 초록이다(테스트는 stub 세션을 쓴다). 이 스위트가 그 구멍을 막는다.
@Suite("세션 기본값")
struct SessionConfigurationTests {
    @Test("요청 타임아웃은 10초 — 재시도 총 소요를 20초 안에 묶는 유일한 레버다")
    func timeout() {
        #expect(Session.mino().sessionConfiguration.timeoutIntervalForRequest == 10)
    }

    // 캐시가 켜지면 "남이 방금 추가한 핀이 안 보인다" — 이 앱에서 가장 아픈 회귀다.
    @Test("URLCache 를 쓰지 않는다")
    func cacheDisabled() {
        #expect(Session.mino().sessionConfiguration.requestCachePolicy == .reloadIgnoringLocalCacheData)
    }

    @Test("재시도는 1회 — POST 중복 생성을 막기 위해 멱등 메서드로 제한된다")
    func retryPolicy() throws {
        let policy = try #require(Session.mino().interceptor as? RetryPolicy)
        #expect(policy.retryLimit == 1)
        #expect(!policy.retryableHTTPMethods.contains(.post))
        #expect(policy.retryableHTTPMethods.contains(.get))
        // 테스트는 백오프를 0.01 로 덮어쓰므로, 기본값은 여기서만 지켜진다.
        #expect(policy.exponentialBackoffBase == 2)
        #expect(policy.exponentialBackoffScale == 0.5)
    }

    @Test("로거가 실려 있다 — 빠지면 장애 때 남는 단서가 사라진다")
    func loggerAttached() {
        let hasLogger = Session.mino().eventMonitor.monitors.contains { $0 is NetworkLogger }
        #expect(hasLogger)
    }
}
