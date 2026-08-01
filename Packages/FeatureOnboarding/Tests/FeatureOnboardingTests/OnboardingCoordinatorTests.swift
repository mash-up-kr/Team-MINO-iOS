import Testing
@testable import FeatureOnboarding

@MainActor
struct OnboardingCoordinatorTests {
    @Test("생성 직후 path 는 비어 있다")
    func startsWithEmptyPath() {
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

    @Test("complete nav → finish 가 1회 발사된다")
    func complete_fires_finish() {
        let coord = OnboardingCoordinator()
        var results: [OnboardingResult] = []
        coord.finish.bind { results.append($0) }

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
}
