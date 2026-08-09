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
        await store.send(.tapAppShare)
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

    @Test("L1 — 마지막 단계에 도달해도 step 은 systemShareSheet 로 남는다 — 완료는 화면 전환이라 단계가 아니다")
    func finishKeepsLastStep() async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.tapShare) {
            $0.step = .shareTarget
        }
        await store.send(.tapShareTarget) {
            $0.step = .systemShareSheet
        }
        await store.send(.tapAppShare)
        store.receiveNavigation(.didFinish)

        #expect(store.currentState.step == .systemShareSheet)
        store.finish()
    }
}
