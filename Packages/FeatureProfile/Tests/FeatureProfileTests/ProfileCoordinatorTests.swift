import Domain
import ProfileSetupUI
import Testing
@testable import FeatureProfile

@MainActor
struct ProfileCoordinatorTests {
    @Test("생성 직후 내비게이션 스택은 비어 있다")
    func startsWithEmptyPath() {
        #expect(ProfileCoordinator(deps: StubProfileDeps()).path.isEmpty)
    }

    @Test("pushProfileSetup nav → 프로필 설정 route 가 push 된다")
    func pushProfileSetup_pushesRoute() {
        let coord = ProfileCoordinator(deps: StubProfileDeps())

        coord.handle(ProfileMainNav.pushProfileSetup)

        #expect(coord.path == [.profileSetup])
    }

    // FR-003 — 저장이 끝나면 마이페이지로 돌아간다. 갱신값은 돌아간 화면이 다시 읽는다.
    @Test("didSave nav → 프로필 설정 화면에서 pop 된다")
    func didSave_popsBackToMain() {
        let coord = ProfileCoordinator(deps: StubProfileDeps())
        coord.handle(ProfileMainNav.pushProfileSetup)

        coord.handle(ProfileSetupNav.didSave)

        #expect(coord.path.isEmpty)
    }

    // 마이페이지 진입점은 수정이다 — `.create` 로 만들어지면 저장이 등록(POST)으로 나가 409 가 된다.
    // 초기값은 여기서 채우지 않는다: `.edit` 는 진입 후 스스로 조회한다.
    @Test("프로필 설정 Store 는 edit 모드로 만들어진다")
    func makeProfileSetupStore_isEditMode() {
        let coord = ProfileCoordinator(deps: StubProfileDeps())

        let store = coord.makeProfileSetupStore()

        #expect(store.state.mode == .edit)
        // edit 는 조회가 끝나야 보여줄 게 생긴다 — 첫 프레임부터 로딩이다.
        #expect(store.state.isLoading)
    }

    // NavigationStack 기본 동작 — pop 된 화면은 다시 push 될 때 빈 상태로 시작한다.
    @Test("make*Store 재호출 시 매번 새 인스턴스를 만든다")
    func makeStores_returnNewInstanceEachTime() {
        let coord = ProfileCoordinator(deps: StubProfileDeps())

        #expect(coord.makeProfileMainStore() !== coord.makeProfileMainStore())
        #expect(coord.makeProfileSetupStore() !== coord.makeProfileSetupStore())
    }

    // handle 직접 호출 테스트는 이 배선이 끊겨도 통과하므로 별도로 둔다(OnboardingCoordinatorTests 선례).
    @Test("배선 — ProfileMain Store 의 tapEditProfile 이 path 에 반영된다")
    func profileMainStore_isWiredToPath() async {
        let coord = ProfileCoordinator(deps: StubProfileDeps())

        let store = coord.makeProfileMainStore()
        store.send(.profileLoaded(.stub()))
        store.send(.tapEditProfile)

        for _ in 0..<1000 where coord.path.isEmpty {
            await Task.yield()
        }
        #expect(coord.path == [.profileSetup])
    }
}
