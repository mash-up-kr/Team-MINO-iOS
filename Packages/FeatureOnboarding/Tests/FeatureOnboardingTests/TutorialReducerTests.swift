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

    @Test("L2 — tapAppShare 는 didFinish 를 알린다 — 완료 화면으로 갈지는 flow 몫이다")
    func tapAppShare_notifiesDidFinish() async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.tapShare) {
            $0.step = .shareTarget
        }
        await store.send(.tapShareTarget) {
            $0.step = .systemShareSheet
        }
        await store.send(.tapAppShare) {
            $0.step = .finished
        }
        store.receiveNavigation(.didFinish)

        store.finish()
    }

    @Test("L2 — 마지막 조작을 두 번 해도 didFinish 는 한 번만 나간다 — 완료 화면 이중 push 차단")
    func tapAppShare_twice_finishesOnce() async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.tapShare) {
            $0.step = .shareTarget
        }
        await store.send(.tapShareTarget) {
            $0.step = .systemShareSheet
        }
        await store.send(.tapAppShare) {
            $0.step = .finished
        }
        store.receiveNavigation(.didFinish)

        // 두 번째 탭은 .finished 가드에 걸려 아무것도 내보내지 않는다
        await store.send(.tapAppShare)

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

    @Test("L2 — 1단계에서 tapAppShare 가 들어와도 didFinish 를 알리지 않는다 — 완료 화면 무단 점프 차단")
    func tapAppShare_beforeLastStep_doesNotFinish() async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.tapAppShare)

        await store.send(.tapShare) {
            $0.step = .shareTarget
        }
        await store.send(.tapAppShare)

        // finish 가 미수신 navigation 잔여를 검사한다 — didFinish 가 나갔다면 여기서 실패한다
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

    @Test("L1 — 1단계에서 2단계 액션이 들어와도 단계를 건너뛰지 않는다")
    func tapShareTarget_atFirstStep_doesNotSkipAhead() async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.tapShareTarget)

        #expect(store.currentState.step == .shareGuide)
        store.finish()
    }
}
