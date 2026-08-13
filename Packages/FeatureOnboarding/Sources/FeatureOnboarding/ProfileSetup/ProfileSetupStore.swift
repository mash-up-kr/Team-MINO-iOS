import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일
/// 이름 최소 길이. 화면이 안내 문구로 보여주는 값과 저장 활성 판정이 어긋나지 않도록 한 곳에서만 정의한다
/// (`ProfileSetupContent` 가 같은 값을 읽는다).
/// 안내 문구의 "한글·영문" 제약은 아직 미구현 — 방 이름의 "한글·영문·숫자만"도 마찬가지다.
enum ProfileSetupLimit {
    static let minimumNameLength = 2
}

struct ProfileSetupState: Equatable {
    var name: String = ""
    var selectedCharacterIndex: Int?

    /// 앞뒤 공백을 뺀 이름이 최소 길이를 넘어야 저장할 수 있다 — ProfileSetupContent 의 `isSaveEnabled` 계약.
    var isSaveEnabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= ProfileSetupLimit.minimumNameLength
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
