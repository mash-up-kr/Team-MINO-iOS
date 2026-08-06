import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일
public struct CreateRoomState: Equatable {
    public var roomName: String = ""
    public var roomDescription: String = ""
    public var selectedColorIndex: Int?

    public init() {}

    /// 공백만 있는 이름은 생성 비활성 — CreateRoomContent 의 `isCreateEnabled` 계약.
    public var isCreateEnabled: Bool {
        !roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public enum CreateRoomAction: Equatable {
    case roomNameChanged(String)
    case roomDescriptionChanged(String)
    case selectColor(Int)
    case tapNext
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

/// 입력 길이 상한. reduce 가 자르는 값과 화면이 안내·카운터로 보여주는 값이 어긋나면
/// 카운터가 거짓말을 하므로 한 곳에서만 정의한다(`CreateRoomContent` 가 같은 값을 읽는다).
public enum CreateRoomLimit {
    public static let name = 15
    public static let description = 20
}

public func createRoomReducer() -> (inout CreateRoomState, CreateRoomAction) -> Effect<CreateRoomAction, CreateRoomNav> {
    { state, action in
        switch action {
        case .roomNameChanged(let name):
            state.roomName = String(name.prefix(CreateRoomLimit.name))
            return .none
        case .roomDescriptionChanged(let description):
            state.roomDescription = String(description.prefix(CreateRoomLimit.description))
            return .none
        case .selectColor(let index):
            state.selectedColorIndex = index
            return .none
        case .tapNext:
            return .navigate(.didCreateRoom)
        case .tapSkip:
            return .navigate(.didSkip)
        }
    }
}
