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

    // MARK: - Dependencies / Lifecycle
    // 편집 자체에 아직 의존이 없어 deps 를 받지 않는다.
    // 편집 저장 등 UseCase 가 생기면 자기 전용 프로토콜(예: MemberEditDeps)을 정의해 받고,
    // 부모는 factory 로 주입한다. (DI = Coordinator 별 좁은 deps 프로토콜)
    public init() {}

    // MARK: - Flow Control
    public func save(_ name: String) { finish(.saved(name)) }
    public func cancel() { finish(.cancelled) }
}
