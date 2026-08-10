import FlowCoordination
import Observation
import RoomCreationUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — flow 루트에 Coordinator(Route enum 포함), 화면마다 폴더
public enum OnboardingRoute: Hashable {
    case createRoom
    case inviteFriends
    case tutorial
}

/// 온보딩 종료 보고. 수집값(이름·컬러 등)은 동반하지 않는다 — plan/pr1/persistent/decisions.md 결정 B
public enum OnboardingResult: Equatable, Sendable {
    case completed
}

/// 온보딩 flow 1회당 **새 인스턴스**를 만들어 쓴다.
///
/// `path` 와 `finish` 발사 여부가 1회 실행분 상태라, 완주한 인스턴스를 재사용하면
/// 마지막 화면부터 뜨고 `finish` 도 다시 발사되지 않는다. 앱 수명 동안 하나를 들고 있는
/// 탭 Coordinator 들과 보유 방식이 다르다.
@Observable
@MainActor
public final class OnboardingCoordinator: Coordinator {
    public var path: [OnboardingRoute] = []
    public var sheet: Never? = nil
    public var cover: Never? = nil
    public let finish = FlowFinish<OnboardingResult>()

    public init() {}

    // Store 를 캐시하지 않는다 — NavigationStack 기본 동작을 그대로 따르기 위해서다.
    // pop 되면 그 화면의 뷰와 @State Store 가 함께 버려지고, 다시 push 하면 빈 상태로 시작한다.
    // 반대로 스택에 남아 있는 화면(pop 해서 돌아간 화면)은 뷰가 살아 있어 입력값이 그대로 유지된다.

    func makeProfileSetupStore() -> ProfileSetupStore {
        let store = ProfileSetupStore(ProfileSetupState(), reduce: profileSetupReducer())
        store.observeNavigation { [weak self] in self?.handle($0) }
        return store
    }

    func makeCreateRoomStore() -> CreateRoomStore {
        let store = CreateRoomStore(CreateRoomState(), reduce: createRoomReducer())
        store.observeNavigation { [weak self] in self?.handle($0) }
        return store
    }

    func makeTutorialStore() -> TutorialStore {
        let store = TutorialStore(TutorialState(), reduce: tutorialReducer())
        store.observeNavigation { [weak self] in self?.handle($0) }
        return store
    }

    func makeInviteFriendsStore() -> InviteFriendsStore {
        let store = InviteFriendsStore(InviteFriendsState(), reduce: inviteFriendsReducer())
        store.observeNavigation { [weak self] in self?.handle($0) }
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
        case .didCreateRoom:
            push(.inviteFriends)
        case .didSkip:
            // 건너뛰기 목적지가 기획에 없어 비워둔다 — 추측으로 넘기지 않는다.
            // (Figma Flow 2 는 "생성 안 하면 다음 접속에 유도"라 건너뛴 사실을 남겨야 하는데 저장할 곳이 없다)
            break
        }
    }

    func handle(_ nav: InviteFriendsNav) {
        switch nav {
        case .complete:
            push(.tutorial)
        }
    }

    func handle(_ nav: TutorialNav) {
        switch nav {
        case .didSkip:
            // 건너뛰기 목적지(방 리스트)가 온보딩 밖이라 비워둔다 — 온보딩을 끝내고 나갈
            // 지점이 정해지면 finish(.completed) 로 이어진다.
            break
        }
    }
}
