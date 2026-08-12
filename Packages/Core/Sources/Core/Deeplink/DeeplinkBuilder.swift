import Foundation

/// 목적지 값을 공유 가능한 URL 로 만든다. 경로 문법은 파서와 같은 곳(`Deeplink.segments`)을 쓴다.
public struct DeeplinkBuilder: Sendable {
    private let configuration: DeeplinkConfiguration

    public init(configuration: DeeplinkConfiguration) {
        self.configuration = configuration
    }

    /// 남에게 공유하는 링크. 앱이 없으면 웹으로 열려 그 페이지가 fallback 이 된다.
    public func webURL(for deeplink: Deeplink) -> URL? {
        guard let segments = urlSafeSegments(of: deeplink) else { return nil }
        return makeURL(scheme: "https", host: configuration.host, segments: segments)
    }

    /// 인앱 브라우저(카카오톡 등)가 Universal Link 를 삼켰을 때 앱으로 되돌리는 링크.
    public func appURL(for deeplink: Deeplink) -> URL? {
        // 파서의 custom scheme 분기와 짝 — 첫 세그먼트가 host 자리에 온다.
        guard let segments = urlSafeSegments(of: deeplink), let host = segments.first else { return nil }
        return makeURL(scheme: configuration.scheme, host: host, segments: Array(segments.dropFirst()))
    }

    /// 하나라도 세그먼트를 깨뜨리면 링크를 만들지 않는다 — 우리가 읽지 못할 링크를 뿌리지 않기 위해.
    private func urlSafeSegments(of deeplink: Deeplink) -> [String]? {
        let segments = deeplink.segments
        return segments.allSatisfy(Deeplink.isValidSegment) ? segments : nil
    }

    private func makeURL(scheme: String, host: String, segments: [String]) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = segments.isEmpty ? "" : "/" + segments.joined(separator: "/")
        return components.url
    }
}
