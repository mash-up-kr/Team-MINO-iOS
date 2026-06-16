import FlowCoordination
import SwiftUI

/// 편집 flow 의 결과. `FlowFinish<EditResult>` 로 부모에게 1회 보고된다.
public enum EditResult: Equatable, Sendable {
    case saved(String)
    case cancelled
}

/// 편집 flow 내부에는 추가 화면이 없으므로 Route 는 비어 있다.
public enum MemberEditRoute: Hashable {}

/// sheet 로 띄워지는 자식 Coordinator. 완료/취소를 `finish` 채널로 부모에 보고한다.
@Observable
@MainActor
public final class MemberEditCoordinator: Coordinator {
    // MARK: - Capabilities
    public var path: [MemberEditRoute] = []
    public var sheet: Never? = nil
    public var cover: Never? = nil
    public let finish = FlowFinish<EditResult>()

    // MARK: - Dependencies / Lifecycle  (deps 주입 — 자식도 같은 번들을 받는다)
    private let deps: MemberDeps
    public init(deps: MemberDeps) { self.deps = deps }

    // MARK: - Flow Control
    public func save(_ name: String) { finish(.saved(name)) }
    public func cancel() { finish(.cancelled) }
}
