import Domain
import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일
public struct CreateRoomState: Equatable {
    public var roomName: String = ""
    public var roomDescription: String = ""
    public var selectedColorIndex: Int?

    public init() {}

    /// 이름 규칙(공백만 금지)은 Domain `RoomName` 이 정의한다 — CreateRoomContent 의 `isCreateEnabled` 계약.
    public var isCreateEnabled: Bool {
        RoomName(roomName) != nil
    }
}

public enum CreateRoomAction: Equatable {
    case roomNameChanged(String)
    case roomDescriptionChanged(String)
    case selectColor(Int)
    case tapCreate
    case tapSkip
}

/// 목적지가 아니라 **일어난 일**로 이름 붙인다 — 이 화면은 온보딩과 방리스트가 함께 쓰는데
/// 방 생성 뒤 어디로 갈지는 진입점마다 다르다. `goToInviteFriends` 처럼 목적지를 박으면
/// 다른 곳으로 보내는 소비자에서 이름이 거짓말이 된다.
public enum CreateRoomNav: Equatable, Sendable {
    case didCreateRoom
    case didSkip
}

public typealias CreateRoomStore = Store<CreateRoomState, CreateRoomAction, CreateRoomNav>

public func createRoomReducer() -> (inout CreateRoomState, CreateRoomAction) -> Effect<CreateRoomAction, CreateRoomNav> {
    { state, action in
        switch action {
        case .roomNameChanged(let name):
            state.roomName = RoomName.clampedDraft(name)
            return .none
        case .roomDescriptionChanged(let description):
            state.roomDescription = RoomMemo.clampedDraft(description)
            return .none
        case .selectColor(let index):
            state.selectedColorIndex = index
            return .none
        case .tapCreate:
            // 뷰의 .disabled 는 UI 레이어 방어라 뷰가 바뀌면 뚫린다 — 전환 조건은 여기서도 지킨다.
            // (.tapSkip 은 건너뛰기라 조건 없이 통과한다)
            guard state.isCreateEnabled else { return .none }
            return .navigate(.didCreateRoom)
        case .tapSkip:
            return .navigate(.didSkip)
        }
    }
}
