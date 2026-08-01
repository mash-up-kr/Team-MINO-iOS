import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일
struct ProfileSetupState: Equatable {
    var name: String = ""
    var selectedCharacterIndex: Int?

    /// 공백만 있는 이름은 저장 비활성 — ProfileSetupContent 의 `isSaveEnabled` 계약.
    var isSaveEnabled: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum ProfileSetupAction: Equatable {
    case nameChanged(String)
    case selectCharacter(Int)
    case tapClear
    case tapNext
}

enum ProfileSetupNav: Equatable, Sendable {
    case goToCreateRoom
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
        case .tapNext:
            return .navigate(.goToCreateRoom)
        }
    }
}
