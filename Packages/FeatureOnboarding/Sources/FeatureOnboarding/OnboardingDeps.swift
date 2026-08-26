import Domain

// [Convention] .claude/docs/mvi-coordinator-di.md 4절 — Coordinator 는 자기가 쓰는 의존만 담은 좁은 프로토콜을 받는다.
/// 온보딩 flow 가 쓰는 의존.
///
/// 온보딩은 프로필을 **만들기만** 한다 — 조회·수정은 마이페이지 몫이라 여기 없다.
public protocol OnboardingDeps: Sendable {
    var registerProfile: RegisterProfileUseCase { get }
    var createRoom: CreateRoomUseCase { get }
}
