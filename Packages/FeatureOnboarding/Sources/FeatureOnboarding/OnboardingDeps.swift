import Core
import Domain

// [Convention] .claude/docs/mvi-coordinator-di.md 4절 — Coordinator 는 자기가 쓰는 의존만 담은 좁은 프로토콜을 받는다.
/// 온보딩 flow 가 쓰는 의존.
///
/// 온보딩은 프로필을 **만들기만** 한다 — 조회·수정은 마이페이지 몫이라 여기 없다.
public protocol OnboardingDeps: Sendable {
    var registerProfile: RegisterProfileUseCase { get }
    var createRoom: CreateRoomUseCase { get }
    var fetchInviteCode: FetchInviteCodeUseCase { get }
    /// 초대 링크의 스킴·호스트. 서버는 코드만 주고 링크는 클라이언트가 조립한다.
    var deeplink: DeeplinkConfiguration { get }
}
