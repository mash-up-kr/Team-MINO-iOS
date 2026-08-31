import FlowCoordination
import RoomShareUI
import Observation
import RoomCreationUI

/// 이 flow 안에는 추가 화면이 없어 Route 가 비어 있다.
/// (화면이 늘면 그때 재귀 패턴대로 자체 `NavigationStack` 을 연다 —
/// `.claude/docs/mvi-coordinator-di-extensions.md` "2단 중첩")
enum RoomShareCreateRoomRoute: Hashable {}

/// 공유 시트 **위에** 커버로 뜨는 자식 Coordinator (기획 011-1 ③).
///
/// 시트를 닫고 탭 스택에 push 하지 않는 이유: 시트가 사라지면 고르던 방 선택이 함께 사라진다.
/// 시트를 살려 둔 채 그 위를 덮으려면 커버가 시트 **안**에 붙어야 하고
/// (``RoomShareSheet``), 그 커버가 여는 flow 를 이 Coordinator 가 소유한다.
///
/// 저장 탭이 헤더 "+" 로 여는 같은 화면(``ArchiveRoute/createRoom``)과 Store 팩토리가 갈리는 건
/// **끝났을 때 갈 곳이 다르기** 때문이다 — 그쪽은 `pop()`, 이쪽은 시트로 결과 보고다.
@Observable
@MainActor
final class RoomShareCreateRoomCoordinator: Coordinator, Identifiable {
    var path: [RoomShareCreateRoomRoute] = []
    var sheet: Never? = nil
    var cover: Never? = nil
    let finish = FlowFinish<RoomShareCreateRoomResult>()

    private let deps: RoomShareCreateRoomDeps

    init(deps: RoomShareCreateRoomDeps) {
        self.deps = deps
    }

    func makeRoomFormStore() -> RoomFormStore {
        RoomCreationUI.makeRoomFormStore(
            .create(create: deps.createRoom),
            handle: { [weak self] in self?.handle($0) }
        )
    }

    /// 폼이 끝났다. 커버를 닫는 일은 `flowRoot` 가 하고, 여기서는 결과만 보고한다.
    func handle(_ nav: RoomFormNav) {
        switch nav {
        case .didSubmit:
            finish(.created)
        // 이 진입점은 건너뛰기를 노출하지 않지만(`showsSkip: false`) 폼이 낼 수 있는 값이라 함께 받는다.
        case .didCancel, .didSkip:
            finish(.cancelled)
        }
    }
}
