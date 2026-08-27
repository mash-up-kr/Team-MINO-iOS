import Core
import FlowCoordination
import Observation
import ProfileSetupUI
import RoomCreationUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — flow 루트에 Coordinator(Route enum 포함), 화면마다 폴더
public enum OnboardingRoute: Hashable {
    case createRoom
    case inviteFriends
    case tutorial
}

/// 온보딩 종료 보고. 수집값(이름·컬러 등)은 동반하지 않는다 — 부모가 그 값을 쓰지 않는다.
///
/// 초대 코드만 예외로 동반한다 — 부모가 어느 방을 열지 이 값 없이는 알 수 없다.
/// 두 case 로 나눠 부모가 초대 착지를 빠뜨리면 switch 누락으로 잡히게 한다
/// (`completed(inviteCode: String?)` 로 두면 옵셔널을 조용히 무시해도 컴파일이 통과한다).
public enum OnboardingResult: Equatable, Sendable {
    case completed
    case completedWithInvite(code: String)
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

    /// 초대 링크로 들어왔다면 그 방의 초대 코드.
    ///
    /// 링크 문법 검증은 시스템 경계(`Core.DeeplinkParser`)가 이미 했으므로 여기서 다시 보지 않는다.
    /// 1회 실행분 입력이라 생성자에 둔다 — 대기 중인 딥링크를 온보딩이 훔쳐보는 API 는 필요 없다.
    private let inviteCode: String?
    private let deps: OnboardingDeps

    /// 앞 단계에서 만든 공동방. 친구초대가 초대 코드를 발급하려면 이 값이 필요하다.
    ///
    /// 방을 건너뛰면(`didSkip`) 친구초대까지 함께 건너뛰므로 `nil` 인 채로 그 화면에 닿지 않는다.
    private var createdRoomId: String?

    public init(deps: OnboardingDeps, inviteCode: String? = nil) {
        self.deps = deps
        // 빈 값은 초대로 보지 않는다 — 빈 문자열이 흘러들면 방 생성을 건너뛴 채
        // 열 수 없는 방 코드로 끝나는데, 그 오작동이 조용해서 배선 실수를 못 잡는다.
        self.inviteCode = inviteCode?.nilIfEmpty
    }

    // Store 를 캐시하지 않는다 — NavigationStack 기본 동작을 그대로 따르기 위해서다.
    // pop 되면 그 화면의 뷰와 @State Store 가 함께 버려지고, 다시 push 하면 빈 상태로 시작한다.
    // 반대로 스택에 남아 있는 화면(pop 해서 돌아간 화면)은 뷰가 살아 있어 입력값이 그대로 유지된다.

    func makeProfileSetupStore() -> ProfileSetupStore {
        // 온보딩은 프로필을 만들기만 한다 — 조회·수정 UseCase 를 들지 않는다.
        ProfileSetupUI.makeProfileSetupStore(
            .create(register: deps.registerProfile),
            handle: { [weak self] in self?.handle($0) }
        )
    }

    func makeRoomFormStore() -> RoomFormStore {
        RoomCreationUI.makeRoomFormStore(
            .create(create: deps.createRoom),
            handle: { [weak self] in self?.handle($0) }
        )
    }

    func makeTutorialStore() -> TutorialStore {
        TutorialStore(TutorialState(), reduce: tutorialReducer(), handle: { [weak self] in self?.handle($0) })
    }

    func makeInviteFriendsStore() -> InviteFriendsStore {
        // 방 생성(didSubmit)이 실어 보낸 id 를 그대로 넘긴다. 이 화면은 방을 만든 직후에만
        // 열리므로 값이 있다 — 없으면 화면이 초대 버튼을 잠근다(잘못된 방으로 초대하지 않는다).
        RoomCreationUI.makeInviteFriendsStore(
            roomId: createdRoomId,
            deps: InviteFriendsDeps(fetchInviteCode: deps.fetchInviteCode, deeplink: deps.deeplink),
            handle: { [weak self] in self?.handle($0) }
        )
    }

    func handle(_ nav: ProfileSetupNav) {
        switch nav {
        case .didSave:
            // 이미 초대받은 방이 있어 방을 만들고 친구를 부르는 두 스텝이 무의미하다.
            push(inviteCode == nil ? .createRoom : .tutorial)
        }
    }

    func handle(_ nav: RoomFormNav) {
        switch nav {
        case .didSubmit(let roomId):
            createdRoomId = roomId
            push(.inviteFriends)
        // 방을 만들지 않았으면 초대할 방도 없어 친구초대까지 함께 건너뛴다.
        case .didSkip:
            push(.tutorial)
        // 온보딩엔 뒤로가기가 없어(디자인 ⑦) 실제로는 오지 않는다. 와도 되돌아갈 곳이 프로필 설정뿐이라 pop.
        case .didCancel:
            pop()
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
        // 어디로 보낼지(방 리스트 vs 초대받은 방)는 결과를 받는 부모가 정한다.
        case .didSkip, .didFinish:
            if let inviteCode {
                finish(.completedWithInvite(code: inviteCode))
            } else {
                finish(.completed)
            }
        }
    }
}
