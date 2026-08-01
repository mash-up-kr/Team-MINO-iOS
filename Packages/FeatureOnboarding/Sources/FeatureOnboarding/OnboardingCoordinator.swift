import FlowCoordination
import Observation

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — flow 루트에 Coordinator(Route enum 포함), 화면마다 폴더
public enum OnboardingRoute: Hashable {
    case createRoom
    case inviteFriends
}

/// 온보딩 종료 보고. 수집값(이름·컬러 등)은 동반하지 않는다 — plan/pr1/persistent/decisions.md 결정 B
public enum OnboardingResult: Equatable, Sendable {
    case completed
}

@Observable
@MainActor
public final class OnboardingCoordinator: Coordinator {
    public var path: [OnboardingRoute] = []
    public var sheet: Never? = nil
    public var cover: Never? = nil
    public let finish = FlowFinish<OnboardingResult>()

    // 입력값 유지 계약: 뒤로 갔다 다시 push해도 화면 상태가 남도록 Coordinator가 Store를 보유한다
    // TODO [AI_IMPL]: make*가 최초 1회 생성 + observeNavigation 배선 후 이 캐시를 반환
    private var profileSetupStore: ProfileSetupStore?
    private var createRoomStore: CreateRoomStore?
    private var inviteFriendsStore: InviteFriendsStore?

    public init() {}

    func makeProfileSetupStore() -> ProfileSetupStore {
        fatalError("not implemented")
    }

    func makeCreateRoomStore() -> CreateRoomStore {
        fatalError("not implemented")
    }

    func makeInviteFriendsStore() -> InviteFriendsStore {
        fatalError("not implemented")
    }

    // TODO [AI_IMPL]: .goToCreateRoom → push(.createRoom)
    func handle(_ nav: ProfileSetupNav) {
        fatalError("not implemented")
    }

    // TODO [AI_IMPL]: .goToInviteFriends → push(.inviteFriends)
    func handle(_ nav: CreateRoomNav) {
        fatalError("not implemented")
    }

    // TODO [AI_IMPL]: .complete → finish(.completed)
    func handle(_ nav: InviteFriendsNav) {
        fatalError("not implemented")
    }
}
