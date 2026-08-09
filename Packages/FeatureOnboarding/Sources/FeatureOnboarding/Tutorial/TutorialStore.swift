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
    /// 마지막 조작까지 끝난 상태. 화면은 그대로 두고 완료 화면으로 넘어간다.
    case finished
}

struct TutorialState: Equatable {
    var step: TutorialStep = .shareGuide

    /// 완료로 넘어간 뒤에도 마지막 시트를 그대로 둔다 — 완료 화면이 덮이는 동안 시트가 사라지면
    /// 딤만 남은 화면이 잠깐 비친다.
    var showsSystemShareSheet: Bool {
        step == .systemShareSheet || step == .finished
    }
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
        // 단계마다 현재 step 을 확인한다 — 뷰가 다른 단계의 버튼을 그리지 않는 것에만 기대면,
        // 뷰를 고치는 순간 단계 건너뛰기·역주행이 조용히 열린다.
        case .tapShare:
            guard state.step == .shareGuide else { return .none }
            state.step = .shareTarget
            return .none
        case .tapShareTarget:
            guard state.step == .shareTarget else { return .none }
            state.step = .systemShareSheet
            return .none
        // 완료를 step 으로 남겨 같은 단계에서의 중복 탭을 막는다 — 이게 없으면 빠르게 두 번 눌렀을 때
        // didFinish 가 두 번 나가 완료 화면이 두 번 push 된다.
        case .tapAppShare:
            guard state.step == .systemShareSheet else { return .none }
            state.step = .finished
            return .navigate(.didFinish)
        // 건너뛰기는 어느 단계에서든 나갈 수 있어야 해서 가드하지 않는다.
        case .tapSkip:
            return .navigate(.didSkip)
        }
    }
}
