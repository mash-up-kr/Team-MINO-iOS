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

    // NOTE(커버리지 공백): InviteFriends 화면은 navigate 하는 action 이 하나도 없어
    // `makeInviteFriendsStore` 의 observeNavigation 배선을 Store 쪽에서 검증할 방법이 없다.
    // 라우팅 자체는 위 `complete_fires_finish_once`(handle 직접 호출)가 계속 지킨다.
    // 건너뛰기에 `.navigate(.complete)` 를 되살리면 배선 테스트도 함께 되돌린다.
}
