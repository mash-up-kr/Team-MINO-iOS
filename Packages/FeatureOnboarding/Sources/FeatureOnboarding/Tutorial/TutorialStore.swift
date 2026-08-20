import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일

struct TutorialState: Equatable {
    /// 지금 보고 있는 스텝(0-based). ``TutorialStep/all`` 의 인덱스다.
    var pageIndex: Int = 0
}

enum TutorialAction: Equatable {
    /// 스와이프로 페이지가 바뀜.
    case selectPage(Int)
    case tapSkip
    /// 마지막 스텝의 '꾹 시작하기'.
    case tapStart
}

/// 목적지가 아니라 일어난 일로 이름 붙인다 — 튜토리얼을 끝낸 뒤 어디로 갈지는 flow 몫이다.
enum TutorialNav: Equatable, Sendable {
    case didSkip
    /// 마지막 스텝까지 보고 마쳤다.
    case didFinish
}

typealias TutorialStore = Store<TutorialState, TutorialAction, TutorialNav>

/// - Parameter steps: 보여줄 스텝 목록. 마지막 스텝 판정과 인덱스 범위 검사에 쓴다.
func tutorialReducer(
    steps: [TutorialStep] = TutorialStep.all
) -> (inout TutorialState, TutorialAction) -> Effect<TutorialAction, TutorialNav> {
    { state, action in
        switch action {
        // 범위 밖 인덱스가 state 에 들어가면 뷰가 없는 페이지를 가리켜 화면이 빈 채로 굳는다.
        case .selectPage(let index):
            guard steps.indices.contains(index) else { return .none }
            state.pageIndex = index
            return .none
        // 건너뛰기는 어느 스텝에서든 나갈 수 있어야 해서 가드하지 않는다.
        case .tapSkip:
            return .navigate(.didSkip)
        // CTA 는 마지막 스텝에만 뜨지만, 뷰가 숨기는 것에만 기대면 뷰를 고치는 순간 중간에서도 끝난다.
        case .tapStart:
            guard state.pageIndex == steps.count - 1 else { return .none }
            return .navigate(.didFinish)
        }
    }
}
