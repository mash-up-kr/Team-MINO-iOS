import Foundation

/// 지금 처리할 수 없는 딥링크를 들고 있다가 준비된 쪽이 한 번만 꺼내 간다.
///
/// 쓰이는 곳은 **온보딩을 마치지 않은 사용자가 초대 링크로 들어오는 경로**다. 링크는 도착했지만
/// 프로필이 없어 방에 넣을 수 없으므로, 프로필 설정과 튜토리얼을 마친 뒤에 꺼내 쓴다.
/// 그 사이 앱이 종료돼 보관분이 사라지는 것은 허용한다 — 링크가 대화방에 남아 있어 다시 누르면 된다.
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
