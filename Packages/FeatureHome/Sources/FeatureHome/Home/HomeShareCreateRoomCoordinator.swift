import FlowCoordination
import Observation
import RoomCreationUI
import RoomShareUI

/// 이 flow 안에는 추가 화면이 없어 Route 가 비어 있다.
enum HomeShareCreateRoomRoute: Hashable {}

/// 홈의 공유 시트 **위에** 커버로 뜨는 자식 Coordinator (기획 011-1 ③).
///
/// 저장 탭의 같은 이름 Coordinator 와 별개로 둔다 — flow 는 Feature 가 소유하고
/// (`.claude/docs/mvi-coordinator-di.md` 1절) `*UI` 는 Coordinator·FlowFinish 를 갖지 않는다.
/// 그래서 공유 시트(``RoomShareSheet``)는 이 화면을 **클로저로 받는다**.
///
/// 홈이 방 리스트 시트에서 여는 같은 화면(``HomeRoute/createRoom``)과 갈리는 건 **끝났을 때
/// 갈 곳이 다르기** 때문이다 — 그쪽은 `pop()`, 이쪽은 공유 시트로 결과 보고다.
@Observable
@MainActor
final class HomeShareCreateRoomCoordinator: Coordinator, Identifiable {
    var path: [HomeShareCreateRoomRoute] = []
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
