import Foundation

/// 지금 처리할 수 없는 딥링크를 들고 있다가 준비된 쪽이 한 번만 꺼내 간다.
/// 콜드 스타트·온보딩 중 진입처럼 URL 이 화면보다 먼저 도착하는 경우를 흡수한다.
@MainActor
public final class PendingDeeplink {
    private var stored: Deeplink?

    public init() {}

    /// 보관 중에 새 링크가 오면 나중 것이 이긴다 — 사용자가 마지막에 누른 링크가 의도다.
    public func store(_ deeplink: Deeplink) {
        stored = deeplink
    }

    /// 꺼내면 사라진다 — 같은 링크로 화면이 두 번 뜨는 것을 막는다.
    public func consume() -> Deeplink? {
        defer { stored = nil }
        return stored
    }
}
