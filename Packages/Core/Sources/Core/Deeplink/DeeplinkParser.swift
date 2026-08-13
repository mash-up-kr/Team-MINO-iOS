import Foundation

/// 외부에서 들어온 URL 을 앱의 목적지 값으로 번역한다.
/// 앱의 신뢰 경계 — 알 수 없는 형태는 예외 없이 nil 로 버린다(호출부는 조용히 폴백한다).
///
/// > **딥링크는 "어디로 가자"는 의도일 뿐 권한이 아니다.** custom scheme 은 OS 검증이 없어
/// > 아무 웹페이지나 `gguk://r/<공격자코드>` 를 발사할 수 있다(Universal Link 는 AASA 로
/// > 도메인 소유가 검증된다). 여기서 두 경로를 같은 값으로 환원하는 것은 의도한 설계이므로,
/// > 방 합류처럼 **상태를 바꾸는 동작 앞에는 반드시 사용자 확인 화면을 둔다.**
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

        switch scheme {
        case "https":
            guard components.host?.lowercased() == configuration.host else { return nil }
            return decodedSegments(of: components.percentEncodedPath)
        case configuration.scheme:
            // gguk://r/AB12 는 host="r", path="/AB12" 로 쪼개진다 — host 가 첫 세그먼트다.
            // 소문자화하지 않는다: 이 자리에 대소문자를 구분하는 값(방 ID 등)이 오면 조용히 뭉개진다.
            guard let host = components.percentEncodedHost?.removingPercentEncoding,
                  let pathSegments = decodedSegments(of: components.percentEncodedPath)
            else { return nil }
            return [host] + pathSegments
        default:
            return nil
        }
    }

    /// 퍼센트 인코딩은 **쪼갠 뒤에** 푼다. 먼저 풀면 `%2F` 가 진짜 구분자로 승격돼
    /// 입력이 세그먼트 경계를 조작할 수 있다 (`/r/AB%2F12` → `["r", "AB", "12"]`).
    private func decodedSegments(of percentEncodedPath: String) -> [String]? {
        var segments: [String] = []
        for segment in percentEncodedPath.split(separator: "/") {
            guard let decoded = String(segment).removingPercentEncoding else { return nil }
            segments.append(decoded)
        }
        return segments
    }
}
