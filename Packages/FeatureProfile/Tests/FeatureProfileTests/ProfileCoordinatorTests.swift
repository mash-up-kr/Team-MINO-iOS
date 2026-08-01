import Testing
@testable import FeatureProfile

@MainActor
struct ProfileCoordinatorTests {
    // 지금은 초기 상태 계약만 검증한다. 첫 Route/Store 가 생기는 PR 에서 실제 전환 테스트로 확장한다.
    @Test("생성 직후 내비게이션 스택은 비어 있다")
    func startsWithEmptyPath() {
        #expect(ProfileCoordinator().path.isEmpty)
    }
}
