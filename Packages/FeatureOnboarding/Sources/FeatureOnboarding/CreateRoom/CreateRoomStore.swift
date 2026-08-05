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
        case .tapNext:
            return .navigate(.goToInviteFriends)
        case .tapSkip:
            // 건너뛰기 목적지가 기획에 없어 비워둔다 — 추측으로 넘기지 않는다.
            // (Figma Flow 2 는 "생성 안 하면 다음 접속에 유도"라 건너뛴 사실을 남겨야 하는데 저장할 곳이 없다)
            return .none
        }
    }
}
