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
    /// 완료 화면을 보여주는 단계.
    ///
    /// 완료 화면도 이 화면의 한 단계다 — 별도 라우트로 push 하면 잠시 뒤 온보딩을 끝내는
    /// 타이머만을 위해 Store 를 하나 더 만들게 된다. 단계로 두면 중복 호출도 가드가 함께 막는다.
    case complete
}

struct TutorialState: Equatable {
    var step: TutorialStep = .shareGuide
}

enum TutorialAction: Equatable {
    /// 게시물의 공유 버튼.
    case tapShare
    /// 공유 대상 시트에서 대상을 고름.
    case tapShareTarget
    /// 공유대상 시트를 내림(딤 탭 또는 아래로 드래그).
    case dismissShareTarget
    /// 시스템 공유시트가 닫힘. `completed` 는 **우리 익스텐션(꾹)을 골랐는지**다 —
    /// 다른 앱을 고르거나 시트를 닫으면 false 로 온다(`TutorialShareSheet.isOurShareExtension`).
    case shareSheetFinished(completed: Bool)
    case tapSkip
    /// 완료 화면을 보여준 시간이 지났다 — 자동 전환 타이머가 되돌린다.
    case completeTimerElapsed
}

/// 목적지가 아니라 일어난 일로 이름 붙인다 — 튜토리얼을 끝낸 뒤 어디로 갈지는 flow 몫이다.
enum TutorialNav: Equatable, Sendable {
    case didSkip
    /// 완료 화면까지 보고 마쳤다.
    case didFinish
}

typealias TutorialStore = Store<TutorialState, TutorialAction, TutorialNav>

/// - Parameter autoAdvanceDelay: 완료 화면을 이만큼 보여준 뒤 튜토리얼을 마친다.
///   주입받는 이유는 테스트가 실제로 2초를 기다리지 않게 하기 위해서다 — `TestStore` 는
///   effect 를 끝까지 await 하므로 기본값으로 두면 그 시간만큼 테스트가 멈춘다.
func tutorialReducer(
    autoAdvanceDelay: Duration = .seconds(2)
) -> (inout TutorialState, TutorialAction) -> Effect<TutorialAction, TutorialNav> {
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
        // 내리면 게시물 화면으로 돌아간다 — 공유 버튼을 다시 눌러 이어갈 수 있다.
        case .dismissShareTarget:
            guard state.step == .shareTarget else { return .none }
            state.step = .shareGuide
            return .none
        case .shareSheetFinished(let completed):
            return reduceShareSheetFinished(completed, to: &state, autoAdvanceDelay: autoAdvanceDelay)
        // 완료 단계에서 걸린 타이머만 유효하다 — 단계 순서가 바뀌어 엉뚱한 시점에 도착하면 무시한다.
        case .completeTimerElapsed:
            guard state.step == .complete else { return .none }
            return .navigate(.didFinish)
        // 건너뛰기는 어느 단계에서든 나갈 수 있어야 해서 가드하지 않는다.
        case .tapSkip:
            return .navigate(.didSkip)
        }
    }
}

/// 시스템 공유시트 결과를 단계에 반영하고, 완주면 자동 전환 타이머를 건다.
private func reduceShareSheetFinished(
    _ completed: Bool,
    to state: inout TutorialState,
    autoAdvanceDelay: Duration
) -> Effect<TutorialAction, TutorialNav> {
    guard state.step == .systemShareSheet else { return .none }
    // 꾹을 고르지 않았으면(다른 앱·취소) 공유대상 시트로 되돌린다 — 시스템 공유시트는 우리가
    // 다시 띄울 수단이 없어, 앞 단계로 보내야 사용자가 다시 시도할 수 있다.
    guard completed else {
        state.step = .shareTarget
        return .none
    }
    state.step = .complete
    return .run { send in
        try? await Task.sleep(for: autoAdvanceDelay)
        // 취소됐으면 보내지 않는다 — `try?` 가 CancellationError 를 삼켜서, 이 가드가 없으면
        // 화면을 떠나며 취소된 타이머가 곧바로 온보딩을 끝내버린다.
        guard !Task.isCancelled else { return }
        send(.completeTimerElapsed)
    }
}
