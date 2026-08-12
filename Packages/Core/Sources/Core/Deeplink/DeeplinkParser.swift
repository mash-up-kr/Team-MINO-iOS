import Foundation

/// 외부에서 들어온 URL 을 앱의 목적지 값으로 번역한다.
/// 앱의 신뢰 경계 — 알 수 없는 형태는 예외 없이 nil 로 버린다(호출부는 조용히 폴백한다).
public struct DeeplinkParser: Sendable {
    private let configuration: DeeplinkConfiguration

    public init(configuration: DeeplinkConfiguration) {
        self.configuration = configuration
    }

    public func parse(_ url: URL) -> Deeplink? {
        guard let segments = segments(of: url) else { return nil }
        return Deeplink(segments: segments)
    }

    /// Universal Link 와 custom scheme 을 같은 세그먼트 배열로 환원한다.
    private func segments(of url: URL) -> [String]? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased()
        else { return nil }

        let pathSegments = components.path.split(separator: "/").map(String.init)

        switch scheme {
        case "https":
            // 경로는 RFC 상 대소문자를 구분해 그대로 넘긴다 — host 를 첫 세그먼트로 쓰는 아래 분기와 갈리는 지점이다.
            guard components.host?.lowercased() == configuration.host else { return nil }
            return pathSegments
        case configuration.scheme:
            // gguk://invite/AB12 는 host="invite", path="/AB12" 로 쪼개진다 — host 가 첫 세그먼트다.
            guard let host = components.host?.lowercased() else { return nil }
            return [host] + pathSegments
        default:
            return nil
        }
    }
}
