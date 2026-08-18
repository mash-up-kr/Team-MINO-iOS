import Domain
import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일
struct ProfileSetupState: Equatable {
    var name: String = ""
    var selectedCharacterIndex: Int?

    /// 이름 규칙(트림 후 최소 길이)은 Domain `Nickname` 이 정의한다 — ProfileSetupContent 의 `isSaveEnabled` 계약.
    var isSaveEnabled: Bool {
        Nickname(name) != nil
    }

    /// 지울 것이 있으면 지울 수 있다 — 저장과 조건이 다르다(저장 최소 길이에 못 미치는 1글자도 지움 대상).
    var isClearEnabled: Bool {
        !name.isEmpty
    }
}

enum ProfileSetupAction: Equatable {
    case nameChanged(String)
    case selectCharacter(Int)
    case tapClear
    case tapSave
}

/// 목적지가 아니라 일어난 일로 이름 붙인다 — 저장 뒤 어디로 갈지는 진입 경로마다 다르다
/// (일반 온보딩은 공동방 생성으로, 초대로 들어왔으면 튜토리얼로 간다).
enum ProfileSetupNav: Equatable, Sendable {
    case didSave
}

typealias ProfileSetupStore = Store<ProfileSetupState, ProfileSetupAction, ProfileSetupNav>

func profileSetupReducer() -> (inout ProfileSetupState, ProfileSetupAction) -> Effect<ProfileSetupAction, ProfileSetupNav> {
    { state, action in
        switch action {
        case .nameChanged(let name):
            state.name = name
            return .none
        case .selectCharacter(let index):
            state.selectedCharacterIndex = index
            return .none
        case .tapClear:
            state.name = ""
            return .none
        case .tapSave:
            // 뷰의 .disabled 는 UI 레이어 방어라 뷰가 바뀌면 뚫린다 — 전환 조건은 여기서도 지킨다.
            guard state.isSaveEnabled else { return .none }
            return .navigate(.didSave)
        }
    }
}
