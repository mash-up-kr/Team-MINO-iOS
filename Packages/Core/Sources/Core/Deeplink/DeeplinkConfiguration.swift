import Foundation

/// 딥링크 URL 의 스킴·호스트.
/// 도메인이 아직 확정되지 않았고 dev/prod 가 갈릴 수 있어 하드코딩하지 않고 주입받는다.
public struct DeeplinkConfiguration: Equatable, Sendable {
    /// 인앱 브라우저가 웹으로 열어버렸을 때 앱으로 되돌리는 custom scheme (예: `gguk`).
    public let scheme: String
    /// Universal Link 호스트 (예: `gguk.app`).
    ///
    /// > 정확히 이 호스트만 받는다. AASA 에 `www` 나 서브도메인을 함께 거는지 아직 정해지지 않았는데,
    /// > 걸어놓고 여기 없으면 OS 는 앱을 열어주고 파서는 nil 을 내 **앱이 뜬 채 아무 일도 안 일어난다**
    /// > (브라우저 폴백도 못 한다). 도메인 확정 시 함께 결정해 복수 호스트로 넓힐지 정한다.
    public let host: String

    public init(scheme: String, host: String) {
        // 스킴·호스트는 RFC 상 대소문자를 구분하지 않는다. 비교 지점마다 정규화하지 않도록 여기서 한 번만 낮춘다.
        self.scheme = scheme.lowercased()
        self.host = host.lowercased()
    }
}
