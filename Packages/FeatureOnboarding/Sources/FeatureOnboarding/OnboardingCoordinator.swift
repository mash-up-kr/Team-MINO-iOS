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

/// 온보딩 flow 1회당 **새 인스턴스**를 만들어 쓴다.
///
/// `path`·Store 캐시·`finish` 발사 여부가 모두 1회 실행분 상태라, 완주한 인스턴스를 재사용하면
/// 마지막 화면부터 뜨고 `finish` 도 다시 발사되지 않는다. 앱 수명 동안 하나를 들고 있는
/// 탭 Coordinator 들과 보유 방식이 다르다.
@Observable
@MainActor
public final class OnboardingCoordinator: Coordinator {
    public var path: [OnboardingRoute] = []
    public var sheet: Never? = nil
    public var cover: Never? = nil
    public let finish = FlowFinish<OnboardingResult>()

    // 입력값 유지 계약: 뒤로 갔다 다시 push해도 화면 상태가 남도록 Coordinator가 Store를 보유한다.
    // 뷰가 직접 읽지 않는 보유물이라 관찰 대상에서 뺀다 — body 안에서 읽히면 캐시 쓰기가 그 body를 무효화한다.
    @ObservationIgnored private var profileSetupStore: ProfileSetupStore?
    @ObservationIgnored private var createRoomStore: CreateRoomStore?
    @ObservationIgnored private var inviteFriendsStore: InviteFriendsStore?

    public init() {}

    func makeProfileSetupStore() -> ProfileSetupStore {
        if let profileSetupStore { return profileSetupStore }
        let store = ProfileSetupStore(ProfileSetupState(), reduce: profileSetupReducer())
        store.observeNavigation { [weak self] in self?.handle($0) }
        profileSetupStore = store
        return store
    }

    func makeCreateRoomStore() -> CreateRoomStore {
        if let createRoomStore { return createRoomStore }
        let store = CreateRoomStore(CreateRoomState(), reduce: createRoomReducer())
        store.observeNavigation { [weak self] in self?.handle($0) }
        createRoomStore = store
        return store
    }

    func makeInviteFriendsStore() -> InviteFriendsStore {
        if let inviteFriendsStore { return inviteFriendsStore }
        let store = InviteFriendsStore(InviteFriendsState(), reduce: inviteFriendsReducer())
        store.observeNavigation { [weak self] in self?.handle($0) }
        inviteFriendsStore = store
        return store
    }

    func handle(_ nav: ProfileSetupNav) {
        switch nav {
        case .goToCreateRoom:
            push(.createRoom)
        }
    }

    func handle(_ nav: CreateRoomNav) {
        switch nav {
        case .goToInviteFriends:
            push(.inviteFriends)
        }
    }

    func handle(_ nav: InviteFriendsNav) {
        switch nav {
        case .complete:
            finish(.completed)
        }
    }
}
