import MVI

struct CreateRoomState: Equatable {
    // 골격 PR 이라 상태가 없다. 방 이름·색 필드는 공동방 만들기 화면 PR 에서 들어온다.
}

enum CreateRoomAction: Equatable {
    case tapNext
}

enum CreateRoomNav: Equatable, Sendable {
    case goToInviteFriends
}

typealias CreateRoomStore = Store<CreateRoomState, CreateRoomAction, CreateRoomNav>

func createRoomReducer() -> (inout CreateRoomState, CreateRoomAction) -> Effect<CreateRoomAction, CreateRoomNav> {
    { _, action in
        switch action {
        case .tapNext:
            return .navigate(.goToInviteFriends)
        }
    }
}
