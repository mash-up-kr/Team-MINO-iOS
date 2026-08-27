import RoomCreationUI
import Testing
@testable import FeatureOnboarding

@MainActor
struct OnboardingCoordinatorTests {
    /// 초대 링크로 들어온 경우를 만드는 코드값. 값 자체는 의미 없고 유무만 경로를 바꾼다.
    private static let inviteCode = "AB12"

    @Test("생성 직후 path 는 비어 있다")
    func path_isEmpty_initially() {
        let coord = OnboardingCoordinator()

        #expect(coord.path.isEmpty)
    }

    @Test("didSave nav → path 에 createRoom 이 push 된다")
    func navigate_pushes_createRoom() {
        let coord = OnboardingCoordinator()

        coord.handle(ProfileSetupNav.didSave)

        #expect(coord.path == [.createRoom])
    }

    @Test("초대로 들어왔으면 didSave nav 가 공동방 생성·친구초대를 건너뛰고 튜토리얼로 간다")
    func navigate_withInvite_skipsRoomCreation() {
        let coord = OnboardingCoordinator(inviteCode: Self.inviteCode)

        coord.handle(ProfileSetupNav.didSave)

        #expect(coord.path == [.tutorial])
    }

    @Test("빈 초대 코드는 초대로 보지 않는다 — 열 수 없는 방으로 조용히 끝나는 것을 막는다")
    func blankInviteCode_isNotTreatedAsInvite() {
        var captured: OnboardingResult?

        for blank in ["", " ", "\n"] {
            let coord = OnboardingCoordinator(inviteCode: blank)
            coord.finish.bind { captured = $0 }

            coord.handle(ProfileSetupNav.didSave)
            #expect(coord.path == [.createRoom])

            coord.handle(TutorialNav.didFinish)
            #expect(captured == .completed)
        }
    }

    @Test("didSubmit nav → path 에 createRoom, inviteFriends 가 순서대로 push 된다")
    func navigate_pushes_inviteFriends() {
        let coord = OnboardingCoordinator()

        coord.handle(ProfileSetupNav.didSave)
        coord.handle(RoomFormNav.didSubmit)

        #expect(coord.path == [.createRoom, .inviteFriends])
    }

    @Test("didSkip nav → 친구초대까지 건너뛰고 튜토리얼로 push 한다 — 만든 방이 없어 초대할 것도 없다")
    func createRoomDidSkip_pushesTutorial() {
        let coord = OnboardingCoordinator()

        coord.handle(ProfileSetupNav.didSave)
        coord.handle(RoomFormNav.didSkip)

        #expect(coord.path == [.createRoom, .tutorial])
    }

    @Test("complete nav → 튜토리얼로 push 한다 — 친구초대 건너뛰기의 목적지")
    func complete_pushesTutorial() {
        let coord = OnboardingCoordinator()

        coord.handle(InviteFriendsNav.complete)

        #expect(coord.path == [.tutorial])
    }

    // MARK: - 온보딩 종료

    @Test("didFinish nav → 온보딩을 완주로 끝낸다")
    func didFinish_finishesAsCompleted() {
        let coord = OnboardingCoordinator()
        var captured: OnboardingResult?
        coord.finish.bind { captured = $0 }

        coord.handle(TutorialNav.didFinish)

        #expect(captured == .completed)
    }

    @Test("초대로 들어왔으면 완주 결과에 초대 코드가 실린다 — 부모가 그 방을 열 수 있게")
    func didFinish_withInvite_carriesCode() {
        let coord = OnboardingCoordinator(inviteCode: Self.inviteCode)
        var captured: OnboardingResult?
        coord.finish.bind { captured = $0 }

        coord.handle(TutorialNav.didFinish)

        #expect(captured == .completedWithInvite(code: Self.inviteCode))
    }

    @Test("didSkip nav → 완주와 같은 결과로 온보딩을 끝낸다 — 건너뛰기도 목적지가 같다")
    func didSkip_finishesLikeCompletion() {
        let coord = OnboardingCoordinator()
        var captured: OnboardingResult?
        coord.finish.bind { captured = $0 }

        coord.handle(TutorialNav.didSkip)

        #expect(captured == .completed)
    }

    @Test("초대로 들어와 튜토리얼을 건너뛰어도 초대 코드가 실린다")
    func didSkip_withInvite_carriesCode() {
        let coord = OnboardingCoordinator(inviteCode: Self.inviteCode)
        var captured: OnboardingResult?
        coord.finish.bind { captured = $0 }

        coord.handle(TutorialNav.didSkip)

        #expect(captured == .completedWithInvite(code: Self.inviteCode))
    }

    // MARK: - 전체 경로

    @Test("배선 — 전체 경로: 프로필 저장 → 방 생성 → 친구초대 건너뛰기 → 튜토리얼 → 완료")
    func fullPath_isWiredInOrder() {
        let coord = OnboardingCoordinator()
        var captured: OnboardingResult?
        coord.finish.bind { captured = $0 }

        coord.handle(ProfileSetupNav.didSave)
        coord.handle(RoomFormNav.didSubmit)
        coord.handle(InviteFriendsNav.complete)

        // 튜토리얼 완료 화면은 라우트가 아니라 튜토리얼 화면 안의 단계다.
        #expect(coord.path == [.createRoom, .inviteFriends, .tutorial])

        coord.handle(TutorialNav.didFinish)
        #expect(captured == .completed)
    }

    @Test("배선 — 초대 경로: 프로필 저장 → 튜토리얼 → 초대받은 방으로 종료")
    func invitePath_skipsTwoStepsAndCarriesCode() {
        let coord = OnboardingCoordinator(inviteCode: Self.inviteCode)
        var captured: OnboardingResult?
        coord.finish.bind { captured = $0 }

        coord.handle(ProfileSetupNav.didSave)
        #expect(coord.path == [.tutorial])

        coord.handle(TutorialNav.didFinish)
        #expect(captured == .completedWithInvite(code: Self.inviteCode))
    }

    // NavigationStack 기본 동작 — pop 된 화면은 다시 push 될 때 빈 상태로 시작한다.
    // (스택에 남아 있는 화면의 입력값 유지는 뷰 수명이 보장하므로 Coordinator 가 관여하지 않는다)
    @Test("make*Store 재호출 시 매번 새 인스턴스를 만든다")
    func makeStores_return_new_instance_each_time() {
        let coord = OnboardingCoordinator()

        #expect(coord.makeProfileSetupStore() !== coord.makeProfileSetupStore())
        #expect(coord.makeRoomFormStore() !== coord.makeRoomFormStore())
        #expect(coord.makeInviteFriendsStore() !== coord.makeInviteFriendsStore())
        // 튜토리얼은 넷 중 유일하게 단계를 들어, 캐시되면 다시 들어갈 때 이전 단계부터 시작한다.
        #expect(coord.makeTutorialStore() !== coord.makeTutorialStore())
    }

    // 아래 5건은 make*Store 안의 observeNavigation 배선을 production Store 로 지난다.
    // handle 직접 호출 테스트는 이 배선이 끊겨도 통과하므로 별도로 둔다.

    /// 구독 Task 가 결과를 전달할 때까지 기다린다. 상한을 두어 회귀 시 hang 없이 끝난다
    /// (StoreTests 선례).
    private func waitUntil(_ isDone: () -> Bool) async {
        for _ in 0..<1000 where !isDone() {
            await Task.yield()
        }
    }

    @Test("배선 — ProfileSetup Store 의 tapSave 가 path 에 반영된다")
    func profileSetupStore_isWiredToPath() async {
        let coord = OnboardingCoordinator()

        let store = coord.makeProfileSetupStore()
        store.send(.nameChanged("민호"))   // reduce 가 저장 조건을 가드하므로 유효한 이름을 먼저 넣는다
        store.send(.tapSave)

        await waitUntil { !coord.path.isEmpty }
        #expect(coord.path == [.createRoom])
    }

    @Test("배선 — 초대로 들어왔을 때 ProfileSetup Store 의 tapSave 가 튜토리얼로 보낸다")
    func profileSetupStore_withInvite_isWiredToTutorial() async {
        let coord = OnboardingCoordinator(inviteCode: Self.inviteCode)

        let store = coord.makeProfileSetupStore()
        store.send(.nameChanged("민호"))
        store.send(.tapSave)

        await waitUntil { !coord.path.isEmpty }
        #expect(coord.path == [.tutorial])
    }

    @Test("배선 — RoomForm Store 의 저장 확인이 path 에 반영된다")
    func createRoomStore_isWiredToPath() async {
        let coord = OnboardingCoordinator()

        let store = coord.makeRoomFormStore()
        store.send(.roomNameChanged("민호야 잘하자"))   // reduce 가 생성 조건을 가드하므로 이름을 먼저 넣는다
        store.send(.tapSubmit)                        // 확인 다이얼로그를 띄우기만 한다
        store.send(.confirmSubmit)

        await waitUntil { !coord.path.isEmpty }
        #expect(coord.path == [.inviteFriends])
    }

    @Test("배선 — RoomForm Store 의 건너뛰기가 path 에 반영된다")
    func createRoomStore_skip_isWiredToPath() async {
        let coord = OnboardingCoordinator()

        let store = coord.makeRoomFormStore()
        store.send(.tapSkip)   // 건너뛰기는 이름 입력 없이도 통과한다

        await waitUntil { !coord.path.isEmpty }
        #expect(coord.path == [.tutorial])
    }

    @Test("배선 — InviteFriends Store 의 건너뛰기가 path 에 반영된다")
    func inviteFriendsStore_isWiredToPath() async {
        let coord = OnboardingCoordinator()

        let store = coord.makeInviteFriendsStore()
        store.send(.tapComplete)

        await waitUntil { !coord.path.isEmpty }
        #expect(coord.path == [.tutorial])
    }

    // 건너뛰기로 배선을 지난다 — 완주(didFinish)와 같은 채널이라 둘 중 하나면 배선이 확인된다
    // (완주 조건 자체는 TutorialReducerTests 가 본다).
    @Test("배선 — Tutorial Store 의 건너뛰기가 finish 로 이어진다")
    func tutorialStore_isWiredToFinish() async {
        let coord = OnboardingCoordinator()
        var captured: OnboardingResult?
        coord.finish.bind { captured = $0 }

        let store = coord.makeTutorialStore()
        store.send(.tapSkip)

        await waitUntil { captured != nil }
        #expect(captured == .completed)
    }
}
