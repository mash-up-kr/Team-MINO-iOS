import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일
struct CreateRoomState: Equatable {
    var roomName: String = ""
    var roomDescription: String = ""
    var selectedColorIndex: Int?

    /// 공백만 있는 이름은 생성 비활성 — CreateRoomContent 의 `isCreateEnabled` 계약.
    var isCreateEnabled: Bool {
        !roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum CreateRoomAction: Equatable {
    case roomNameChanged(String)
    case roomDescriptionChanged(String)
    case selectColor(Int)
    case tapNext
    case tapSkip
}

enum CreateRoomNav: Equatable, Sendable {
    case goToInviteFriends
}

typealias CreateRoomStore = Store<CreateRoomState, CreateRoomAction, CreateRoomNav>

// CreateRoomContent 헬퍼 문구 계약: 방 이름 "공백 포함 15자 이내", 방 설명 카운터 "/20"
private let roomNameLimit = 15
private let roomDescriptionLimit = 20

func createRoomReducer() -> (inout CreateRoomState, CreateRoomAction) -> Effect<CreateRoomAction, CreateRoomNav> {
    { state, action in
        switch action {
        case .roomNameChanged(let name):
            state.roomName = String(name.prefix(roomNameLimit))
            return .none
        case .roomDescriptionChanged(let description):
            state.roomDescription = String(description.prefix(roomDescriptionLimit))
            return .none
        case .selectColor(let index):
            state.selectedColorIndex = index
            return .none
        case .tapNext, .tapSkip:
            // 건너뛰기도 방 생성하기와 동일하게 다음 화면(친구초대)으로 넘어간다 — 기획 미명시, 온보딩 관례.
            return .navigate(.goToInviteFriends)
        }
    }
}
