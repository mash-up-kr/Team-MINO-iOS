import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일

struct TutorialState: Equatable {
    var pageIndex: Int = 0
}

enum TutorialAction: Equatable {
    case selectPage(Int)
    case tapSkip
    case tapStart
}

/// 목적지가 아니라 일어난 일로 이름 붙인다 — 튜토리얼을 끝낸 뒤 어디로 갈지는 flow 몫이다.
enum TutorialNav: Equatable, Sendable {
    case didSkip
    case didFinish
}

typealias TutorialStore = Store<TutorialState, TutorialAction, TutorialNav>

func tutorialReducer(
    stepCount: Int = TutorialStep.all.count
) -> (inout TutorialState, TutorialAction) -> Effect<TutorialAction, TutorialNav> {
    { state, action in
        switch action {
        // 범위 밖 인덱스가 들어가면 뷰가 없는 페이지를 가리켜 화면이 빈 채로 굳는다.
        case .selectPage(let index):
            guard (0..<stepCount).contains(index) else { return .none }
            state.pageIndex = index
            return .none
        case .tapSkip:
            return .navigate(.didSkip)
        // 뷰가 CTA 를 숨기는 것에만 기대면, 뷰를 고치는 순간 중간 스텝에서도 끝난다.
        case .tapStart:
            guard state.pageIndex == stepCount - 1 else { return .none }
            return .navigate(.didFinish)
        }
    }
}
