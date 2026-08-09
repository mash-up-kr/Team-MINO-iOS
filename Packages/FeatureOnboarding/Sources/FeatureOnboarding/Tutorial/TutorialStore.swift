import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일

/// 튜토리얼이 어디까지 진행됐는지. 시트가 오르내리는 한 화면이라 단계를 상태로 든다.
enum TutorialStep: Equatable {
    /// 게시물의 공유 버튼을 눌러보게 하는 단계.
    case shareGuide
    /// 공유 대상 시트가 올라온 단계.
    case shareTarget
    /// 시스템 공유시트가 올라온 단계.
    case systemShareSheet
}

struct TutorialState: Equatable {
    var step: TutorialStep = .shareGuide
}

enum TutorialAction: Equatable {
    /// 게시물의 공유 버튼.
    case tapShare
    /// 공유 대상 시트에서 대상을 고름.
    case tapShareTarget
    /// 시스템 공유시트에서 우리 앱을 고름 — 튜토리얼의 마지막 조작.
    case tapAppShare
    case tapSkip
}

/// 목적지가 아니라 일어난 일로 이름 붙인다 — 튜토리얼을 끝낸 뒤 어디로 갈지는 flow 몫이다.
enum TutorialNav: Equatable, Sendable {
    case didFinish
    case didSkip
}

typealias TutorialStore = Store<TutorialState, TutorialAction, TutorialNav>

func tutorialReducer() -> (inout TutorialState, TutorialAction) -> Effect<TutorialAction, TutorialNav> {
    { state, action in
        switch action {
        case .tapShare:
            state.step = .shareTarget
            return .none
        case .tapShareTarget:
            state.step = .systemShareSheet
            return .none
        case .tapAppShare:
            return .navigate(.didFinish)
        case .tapSkip:
            return .navigate(.didSkip)
        }
    }
}
