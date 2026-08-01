import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일
struct ProfileSetupState: Equatable {
    // 골격 PR 이라 상태가 없다. 이름·캐릭터 컬러 필드는 프로필 설정 화면 PR 에서 들어온다.
}

enum ProfileSetupAction: Equatable {
    case tapNext
}

enum ProfileSetupNav: Equatable, Sendable {
    case goToCreateRoom
}

typealias ProfileSetupStore = Store<ProfileSetupState, ProfileSetupAction, ProfileSetupNav>

func profileSetupReducer() -> (inout ProfileSetupState, ProfileSetupAction) -> Effect<ProfileSetupAction, ProfileSetupNav> {
    { _, action in
        switch action {
        case .tapNext:
            return .navigate(.goToCreateRoom)
        }
    }
}
