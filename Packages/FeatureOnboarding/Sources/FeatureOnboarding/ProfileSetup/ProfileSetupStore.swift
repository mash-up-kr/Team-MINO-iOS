import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일
struct ProfileSetupState: Equatable {
    // TODO [AI_IMPL-PR2]: 이름 입력·캐릭터 컬러 선택 필드 (PR 2 범위 — 이번 PR에서는 빈 상태 유지)
}

enum ProfileSetupAction: Equatable {
    case tapNext
}

enum ProfileSetupNav: Equatable, Sendable {
    case goToCreateRoom
}

typealias ProfileSetupStore = Store<ProfileSetupState, ProfileSetupAction, ProfileSetupNav>

// TODO [AI_IMPL]: .tapNext → .navigate(.goToCreateRoom)
func profileSetupReducer() -> (inout ProfileSetupState, ProfileSetupAction) -> Effect<ProfileSetupAction, ProfileSetupNav> {
    fatalError("not implemented")
}
