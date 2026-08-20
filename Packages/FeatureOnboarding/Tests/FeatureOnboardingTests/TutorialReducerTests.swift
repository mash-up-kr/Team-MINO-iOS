import MVITestSupport
import Testing
@testable import FeatureOnboarding

@MainActor
struct TutorialReducerTests {
    private static let lastIndex = TutorialStep.all.count - 1

    @Test("L1 — selectPage 는 보고 있는 스텝을 바꾼다")
    func selectPage_movesToThatStep() async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.selectPage(2)) {
            $0.pageIndex = 2
        }
        // 되돌아오는 스와이프도 같은 액션으로 들어온다
        await store.send(.selectPage(1)) {
            $0.pageIndex = 1
        }

        store.finish()
    }

    @Test("L1 — 스텝 범위를 벗어난 인덱스는 무시된다", arguments: [-1, TutorialStep.all.count])
    func selectPage_outOfRange_isIgnored(index: Int) async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.selectPage(index))

        #expect(store.currentState.pageIndex == 0)
        store.finish()
    }

    @Test("L2 — 마지막 스텝의 '꾹 시작하기'가 튜토리얼을 끝낸다")
    func tapStart_atLastStep_finishes() async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.selectPage(Self.lastIndex)) {
            $0.pageIndex = Self.lastIndex
        }
        await store.send(.tapStart)
        store.receiveNavigation(.didFinish)

        store.finish()
    }

    // 뷰가 마지막 스텝에서만 CTA 를 그리는 것과 별개로 reduce 가 스스로 막는지 본다
    // (뷰의 조건을 지워도 통과하던 공백이라 가드와 함께 넣었다)
    @Test("L1 — 마지막이 아닌 스텝에서 온 tapStart 는 무시된다")
    func tapStart_beforeLastStep_isIgnored() async {
        let store = TestStore(TutorialState(), reduce: tutorialReducer())

        await store.send(.tapStart)
        await store.send(.selectPage(Self.lastIndex - 1)) {
            $0.pageIndex = Self.lastIndex - 1
        }
        await store.send(.tapStart)

        // finish 가 미수신 navigation 잔여를 검사한다 — didFinish 가 나갔다면 여기서 실패한다
        store.finish()
    }

    @Test("L2 — tapSkip 은 어느 스텝에서든 didSkip 을 알린다", arguments: [0, 2, TutorialStep.all.count - 1])
    func tapSkip_notifiesDidSkip(index: Int) async {
        let store = TestStore(TutorialState(pageIndex: index), reduce: tutorialReducer())

        await store.send(.tapSkip)
        store.receiveNavigation(.didSkip)

        store.finish()
    }
}
