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

    @Test("goToInviteFriends nav → path 에 createRoom, inviteFriends 가 순서대로 push 된다")
    func navigate_pushes_inviteFriends() {
        let coord = OnboardingCoordinator()

        coord.handle(ProfileSetupNav.goToCreateRoom)
        coord.handle(CreateRoomNav.goToInviteFriends)

        #expect(coord.path == [.createRoom, .inviteFriends])
    }

    @Test("complete nav 를 두 번 받아도 finish 는 1회만 발사된다")
    func complete_fires_finish_once() {
        let coord = OnboardingCoordinator()
        var results: [OnboardingResult] = []
        coord.finish.bind { results.append($0) }

        coord.handle(InviteFriendsNav.complete)
        coord.handle(InviteFriendsNav.complete)

        #expect(results == [.completed])
    }

    @Test("make*Store 재호출 시 동일 인스턴스를 반환한다 — 입력값 유지 계약")
    func makeStores_return_cached_instance() {
        let coord = OnboardingCoordinator()

        #expect(coord.makeProfileSetupStore() === coord.makeProfileSetupStore())
        #expect(coord.makeCreateRoomStore() === coord.makeCreateRoomStore())
        #expect(coord.makeInviteFriendsStore() === coord.makeInviteFriendsStore())
    }

    // 아래 3건은 make*Store 안의 observeNavigation 배선을 production Store 로 지난다.
    // handle 직접 호출 테스트는 이 배선이 끊겨도 통과하므로 별도로 둔다.
    // 폴링 대기는 StoreTests 선례를 따른다(회귀 시 hang 없이 유한 종료).

    @Test("배선 — ProfileSetup Store 의 tapNext 가 path 에 반영된다")
    func profileSetupStore_isWiredToPath() async {
        let coord = OnboardingCoordinator()

        coord.makeProfileSetupStore().send(.tapNext)

        for _ in 0..<1000 where coord.path.isEmpty {
            await Task.yield()
        }
        #expect(coord.path == [.createRoom])
    }

    @Test("배선 — CreateRoom Store 의 tapNext 가 path 에 반영된다")
    func createRoomStore_isWiredToPath() async {
        let coord = OnboardingCoordinator()

        coord.makeCreateRoomStore().send(.tapNext)

        for _ in 0..<1000 where coord.path.isEmpty {
            await Task.yield()
        }
        #expect(coord.path == [.inviteFriends])
    }

    @Test("배선 — InviteFriends Store 의 tapComplete 가 finish 를 발사한다")
    func inviteFriendsStore_isWiredToFinish() async {
        let coord = OnboardingCoordinator()
        var results: [OnboardingResult] = []
        coord.finish.bind { results.append($0) }

        coord.makeInviteFriendsStore().send(.tapComplete)

        for _ in 0..<1000 where results.isEmpty {
            await Task.yield()
        }
        #expect(results == [.completed])
    }
}
