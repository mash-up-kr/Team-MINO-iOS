import Testing
@testable import FeatureOnboarding

@MainActor
struct OnboardingCoordinatorTests {
    // TODO [AI_IMPL]: 생성 직후 path 비어 있음
    // TODO [AI_IMPL]: handle(ProfileSetupNav.goToCreateRoom) → path == [.createRoom]
    // TODO [AI_IMPL]: handle(CreateRoomNav.goToInviteFriends) → path == [.createRoom, .inviteFriends]
    // TODO [AI_IMPL]: handle(InviteFriendsNav.complete) → finish 1회 발사(.completed) — bind로 캡처해 단언
    // TODO [AI_IMPL]: make*Store 재호출 시 동일 인스턴스 반환(=== 단언) — 입력값 유지 계약
}
