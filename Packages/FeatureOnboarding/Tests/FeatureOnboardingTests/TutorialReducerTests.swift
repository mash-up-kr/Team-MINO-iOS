import MVITestSupport
import Testing
@testable import FeatureOnboarding

@MainActor
struct TutorialReducerTests {
    @Test("L1 — tapShare 는 공유 대상 시트 단계로 넘어간다")
    func tapShare_movesToShareTarget() async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.tapShare) {
            $0.step = .shareTarget
        }

        store.finish()
    }

    @Test("L1 — tapShareTarget 은 시스템 공유시트 단계로 넘어간다")
    func tapShareTarget_movesToSystemShareSheet() async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.tapShare) {
            $0.step = .shareTarget
        }
        await store.send(.tapShareTarget) {
            $0.step = .systemShareSheet
        }

        store.finish()
    }

    @Test("L2 — 대상을 고르고 닫히면 완료 단계로 넘어가고, 잠시 뒤 스스로 튜토리얼을 마친다")
    func shareSheetFinished_movesToComplete_thenAutoAdvances() async {
        // 지연 0 — 실제 2초를 기다리면 테스트가 그만큼 멈춘다(TestStore 는 effect 를 끝까지 await 한다)
        let store = TestStore(TutorialState(), reduce: tutorialReducer(autoAdvanceDelay: .zero))

        await store.send(.tapShare) {
            $0.step = .shareTarget
        }
        await store.send(.tapShareTarget) {
            $0.step = .systemShareSheet
        }
        await store.send(.shareSheetFinished(completed: true)) {
            $0.step = .complete
        }
        await store.receive(.completeTimerElapsed)
        store.receiveNavigation(.didFinish)

        store.finish()
    }

    @Test("L1 — 공유대상 시트를 내리면 게시물 화면으로 돌아간다 — 다시 공유 버튼을 누를 수 있게")
    func dismissShareTarget_returnsToShareGuide() async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.tapShare) {
            $0.step = .shareTarget
        }
        await store.send(.dismissShareTarget) {
            $0.step = .shareGuide
        }
        // 되돌아간 뒤 다시 진행할 수 있다
        await store.send(.tapShare) {
            $0.step = .shareTarget
        }

        store.finish()
    }

    @Test("L1 — 시스템 공유시트 단계에서 온 dismissShareTarget 은 무시된다 — 딤은 그때도 깔려 있다")
    func dismissShareTarget_atSystemSheet_isIgnored() async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.tapShare) {
            $0.step = .shareTarget
        }
        await store.send(.tapShareTarget) {
            $0.step = .systemShareSheet
        }
        await store.send(.dismissShareTarget)

        #expect(store.currentState.step == .systemShareSheet)
        store.finish()
    }

    @Test("L1 — 공유시트를 취소하면 공유대상 시트로 되돌아간다 — 다시 시도할 수 있게")
    func shareSheetCancelled_returnsToShareTarget() async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.tapShare) {
            $0.step = .shareTarget
        }
        await store.send(.tapShareTarget) {
            $0.step = .systemShareSheet
        }
        await store.send(.shareSheetFinished(completed: false)) {
            $0.step = .shareTarget
        }

        // 취소는 자동 전환 타이머를 걸지 않는다 — 걸렸다면 finish 가 미처리 effect 로 잡는다
        store.finish()
    }

    @Test("L2 — 완료 뒤 같은 결과가 또 와도 완료 단계에 머물고 타이머도 다시 걸리지 않는다 — 중복 차단")
    func shareSheetFinished_twice_staysComplete() async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer(autoAdvanceDelay: .zero))

        await store.send(.tapShare) {
            $0.step = .shareTarget
        }
        await store.send(.tapShareTarget) {
            $0.step = .systemShareSheet
        }
        await store.send(.shareSheetFinished(completed: true)) {
            $0.step = .complete
        }
        // 두 번째 결과는 가드에 걸려 단계를 다시 바꾸지 않는다
        await store.send(.shareSheetFinished(completed: true))

        #expect(store.currentState.step == .complete)
        // 타이머는 한 번만 걸렸다 — 두 번 걸렸다면 finish 가 미처리 effect 로 잡는다
        await store.receive(.completeTimerElapsed)
        store.receiveNavigation(.didFinish)
        store.finish()
    }

    @Test("L2 — tapSkip 은 어느 단계에서든 didSkip 을 알린다")
    func tapSkip_notifiesDidSkip() async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.tapSkip)
        store.receiveNavigation(.didSkip)

        store.finish()
    }

    // 아래 3건은 뷰의 `.disabled` 와 별개로 reduce 가 단계를 지키는지 본다.
    // (`.disabled` 를 지워도 통과하던 공백이라 가드와 함께 넣었다)

    @Test("L1 — 1·2단계에서 공유시트 결과가 들어와도 완료 단계로 뛰지 않는다")
    func shareSheetFinished_beforeLastStep_doesNotComplete() async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.shareSheetFinished(completed: true))

        await store.send(.tapShare) {
            $0.step = .shareTarget
        }
        await store.send(.shareSheetFinished(completed: true))

        #expect(store.currentState.step == .shareTarget)
        store.finish()
    }

    @Test("L1 — 마지막 단계에서 1단계 액션이 들어와도 단계가 되돌아가지 않는다")
    func tapShare_atLastStep_doesNotRewind() async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.tapShare) {
            $0.step = .shareTarget
        }
        await store.send(.tapShareTarget) {
            $0.step = .systemShareSheet
        }
        await store.send(.tapShare)

        #expect(store.currentState.step == .systemShareSheet)
        store.finish()
    }

    @Test("L1 — 완료 단계가 아닐 때 도착한 자동 전환 타이머는 무시된다")
    func completeTimerElapsed_beforeComplete_isIgnored() async {
        // 완료 단계가 아니라 타이머가 걸리지 않으므로 지연을 줄일 필요가 없다
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.completeTimerElapsed)

        #expect(store.currentState.step == .shareGuide)
        // finish 가 미수신 navigation 잔여를 검사한다 — didFinish 가 나갔다면 여기서 실패한다
        store.finish()
    }

    @Test("L1 — 1단계에서 2단계 액션이 들어와도 단계를 건너뛰지 않는다")
    func tapShareTarget_atFirstStep_doesNotSkipAhead() async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.tapShareTarget)

        #expect(store.currentState.step == .shareGuide)
        store.finish()
    }
}
