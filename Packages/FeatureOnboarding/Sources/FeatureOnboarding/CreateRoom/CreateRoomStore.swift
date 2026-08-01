import MVI

struct CreateRoomState: Equatable {
    // TODO [AI_IMPL-PR3]: 방 이름 입력·색 선택(지도 틴트) 필드 (PR 3 범위 — 이번 PR에서는 빈 상태 유지)
}

enum CreateRoomAction: Equatable {
    case tapNext
}

enum CreateRoomNav: Equatable, Sendable {
    case goToInviteFriends
}

typealias CreateRoomStore = Store<CreateRoomState, CreateRoomAction, CreateRoomNav>

// TODO [AI_IMPL]: .tapNext → .navigate(.goToInviteFriends)
func createRoomReducer() -> (inout CreateRoomState, CreateRoomAction) -> Effect<CreateRoomAction, CreateRoomNav> {
    fatalError("not implemented")
}
