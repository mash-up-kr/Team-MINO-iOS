import ProfileSetupUI
import Testing
@testable import FeatureProfile

@MainActor
struct ProfileCoordinatorTests {
    @Test("생성 직후 내비게이션 스택은 비어 있다")
    func startsWithEmptyPath() {
        #expect(ProfileCoordinator(deps: StubProfileDeps()).path.isEmpty)
    }

    @Test("pushProfileSetup nav → 기존 값을 실은 route 가 push 된다")
    func pushProfileSetup_pushesRouteWithPrefill() {
        let coord = ProfileCoordinator(deps: StubProfileDeps())

        coord.handle(ProfileMainNav.pushProfileSetup(nickname: "홍길동", avatarIndex: 7))

        #expect(coord.path == [.profileSetup(nickname: "홍길동", avatarIndex: 7)])
    }

    // FR-003 — 저장이 끝나면 마이페이지로 돌아간다. 갱신값은 돌아간 화면이 다시 읽는다.
    @Test("didSave nav → 프로필 설정 화면에서 pop 된다")
    func didSave_popsBackToMain() {
        let coord = ProfileCoordinator(deps: StubProfileDeps())
        coord.handle(ProfileMainNav.pushProfileSetup(nickname: "홍길동", avatarIndex: 7))

        coord.handle(ProfileSetupNav.didSave)

        #expect(coord.path.isEmpty)
    }

    @Test("프로필 설정 Store 는 기존 값이 채워진 채 만들어진다 — 그래야 편집 화면이 비어 열리지 않는다")
    func makeProfileSetupStore_isPrefilled() {
        let coord = ProfileCoordinator(deps: StubProfileDeps())

        let store = coord.makeProfileSetupStore(nickname: "홍길동", avatarIndex: 7)

        #expect(store.state.name == "홍길동")
        #expect(store.state.selectedCharacterIndex == 7)
        #expect(store.state.isSaveEnabled)
    }

    // NavigationStack 기본 동작 — pop 된 화면은 다시 push 될 때 빈 상태로 시작한다.
    @Test("make*Store 재호출 시 매번 새 인스턴스를 만든다")
    func makeStores_returnNewInstanceEachTime() {
        let coord = ProfileCoordinator(deps: StubProfileDeps())

        #expect(coord.makeProfileMainStore() !== coord.makeProfileMainStore())
        #expect(coord.makeProfileSetupStore(nickname: "", avatarIndex: nil)
                !== coord.makeProfileSetupStore(nickname: "", avatarIndex: nil))
    }

    // handle 직접 호출 테스트는 이 배선이 끊겨도 통과하므로 별도로 둔다(OnboardingCoordinatorTests 선례).
    @Test("배선 — ProfileMain Store 의 tapEditProfile 이 path 에 반영된다")
    func profileMainStore_isWiredToPath() async {
        let coord = ProfileCoordinator(deps: StubProfileDeps())

        let store = coord.makeProfileMainStore()
        store.send(.profileLoaded(.init(nickname: "홍길동", avatarID: 7)))
        store.send(.tapEditProfile)

        for _ in 0..<1000 where coord.path.isEmpty {
            await Task.yield()
        }
        #expect(coord.path == [.profileSetup(nickname: "홍길동", avatarIndex: 7)])
    }
}
