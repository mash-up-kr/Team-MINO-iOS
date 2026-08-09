import RoomCreationUI
import Testing
@testable import FeatureOnboarding

@MainActor
struct OnboardingCoordinatorTests {
    @Test("생성 직후 path 는 비어 있다")
    func path_isEmpty_initially() {
        let coord = OnboardingCoordinator()

        #expect(coord.path.isEmpty)
    }

    @Test("goToCreateRoom nav → path 에 createRoom 이 push 된다")
    func navigate_pushes_createRoom() {
        let coord = OnboardingCoordinator()

        coord.handle(ProfileSetupNav.goToCreateRoom)

        #expect(coord.path == [.createRoom])
    }

    @Test("didCreateRoom nav → path 에 createRoom, inviteFriends 가 순서대로 push 된다")
    func navigate_pushes_inviteFriends() {
        let coord = OnboardingCoordinator()

        coord.handle(ProfileSetupNav.goToCreateRoom)
        coord.handle(CreateRoomNav.didCreateRoom)

        #expect(coord.path == [.createRoom, .inviteFriends])
    }

    @Test("complete nav → 튜토리얼로 push 한다 — 친구초대 건너뛰기의 목적지")
    func complete_pushesTutorial() {
        let coord = OnboardingCoordinator()

        coord.handle(InviteFriendsNav.complete)

        #expect(coord.path == [.tutorial])
    }

    @Test("didFinish nav → 완료 화면으로 push 한다 — 시스템 공유시트에서 우리 앱을 고른 뒤")
    func didFinish_pushesTutorialComplete() {
        let coord = OnboardingCoordinator()

        coord.handle(TutorialNav.didFinish)

        #expect(coord.path == [.tutorialComplete])
    }

    // 온보딩을 끝내고 나갈 지점(방 리스트)이 아직 없어 didSkip 은 아무 데도 보내지 않는다.
    // finish 발사 경로가 생기면 이 테스트가 그 자리를 알려준다.
    @Test("didSkip nav → 아직 목적지가 없어 path 가 변하지 않는다")
    func didSkip_doesNotRoute() {
        let coord = OnboardingCoordinator()

        coord.handle(TutorialNav.didSkip)

        #expect(coord.path.isEmpty)
    }

    @Test("배선 — 전체 경로: 프로필 저장 → 방 생성 → 친구초대 건너뛰기 → 튜토리얼 → 완료")
    func fullPath_isWiredInOrder() {
        let coord = OnboardingCoordinator()

        coord.handle(ProfileSetupNav.goToCreateRoom)
        coord.handle(CreateRoomNav.didCreateRoom)
        coord.handle(InviteFriendsNav.complete)
        coord.handle(TutorialNav.didFinish)

        #expect(coord.path == [.createRoom, .inviteFriends, .tutorial, .tutorialComplete])
    }

    // NavigationStack 기본 동작 — pop 된 화면은 다시 push 될 때 빈 상태로 시작한다.
    // (스택에 남아 있는 화면의 입력값 유지는 뷰 수명이 보장하므로 Coordinator 가 관여하지 않는다)
    @Test("make*Store 재호출 시 매번 새 인스턴스를 만든다")
    func makeStores_return_new_instance_each_time() {
        let coord = OnboardingCoordinator()

        #expect(coord.makeProfileSetupStore() !== coord.makeProfileSetupStore())
        #expect(coord.makeCreateRoomStore() !== coord.makeCreateRoomStore())
        #expect(coord.makeInviteFriendsStore() !== coord.makeInviteFriendsStore())
    }

    // 아래 3건은 make*Store 안의 observeNavigation 배선을 production Store 로 지난다.
    // handle 직접 호출 테스트는 이 배선이 끊겨도 통과하므로 별도로 둔다.
    // 폴링 대기는 StoreTests 선례를 따른다(회귀 시 hang 없이 유한 종료).

    @Test("배선 — ProfileSetup Store 의 tapSave 가 path 에 반영된다")
    func profileSetupStore_isWiredToPath() async {
        let coord = OnboardingCoordinator()

        let store = coord.makeProfileSetupStore()
        store.send(.nameChanged("민호"))   // reduce 가 저장 조건을 가드하므로 유효한 이름을 먼저 넣는다
        store.send(.tapSave)

        for _ in 0..<1000 where coord.path.isEmpty {
            await Task.yield()
        }
        #expect(coord.path == [.createRoom])
    }

    @Test("배선 — CreateRoom Store 의 tapCreate 가 path 에 반영된다")
    func createRoomStore_isWiredToPath() async {
        let coord = OnboardingCoordinator()

        let store = coord.makeCreateRoomStore()
        store.send(.roomNameChanged("민호야 잘하자"))   // reduce 가 생성 조건을 가드하므로 이름을 먼저 넣는다
        store.send(.tapCreate)

        for _ in 0..<1000 where coord.path.isEmpty {
            await Task.yield()
        }
        #expect(coord.path == [.inviteFriends])
    }

    @Test("배선 — InviteFriends Store 의 건너뛰기가 path 에 반영된다")
    func inviteFriendsStore_isWiredToPath() async {
        let coord = OnboardingCoordinator()

        let store = coord.makeInviteFriendsStore()
        store.send(.tapComplete)

        for _ in 0..<1000 where coord.path.isEmpty {
            await Task.yield()
        }
        #expect(coord.path == [.tutorial])
    }

    @Test("배선 — Tutorial Store 의 마지막 조작이 path 에 반영된다")
    func tutorialStore_isWiredToPath() async {
        let coord = OnboardingCoordinator()

        let store = coord.makeTutorialStore()
        store.send(.tapAppShare)

        for _ in 0..<1000 where coord.path.isEmpty {
            await Task.yield()
        }
        #expect(coord.path == [.tutorialComplete])
    }
}
