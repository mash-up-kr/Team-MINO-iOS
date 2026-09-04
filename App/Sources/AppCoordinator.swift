import Core
import Domain
import Feature
import FeatureArchive
import FeatureHome
import FeatureNotification
import FeatureOnboarding
import FeatureProfile
import Logging
import SwiftUI

/// 탭 밖에서 들어오는 이동의 도착지. **장소·방 모두 저장 탭에서 연다** — 홈 탭도 같은 장소 상세를
/// 열 수 있지만, 저장 탭이 방 상세와 장소 상세를 모두 갖고 있어 한 곳으로 모은다.
enum AppDestination: Equatable {
    case place(pin: Pin, room: Room)
    case room(Room)
}

/// 초대 진입이 실패했을 때 띄우는 스낵바. **초대를 없던 것으로 치고 평소 진입으로 보내면서**
/// 이유만 알린다(Flow 6 협의) — 전용 실패 화면을 두지 않는다.
///
/// 뒤 둘을 나누는 기준은 `AppLaunchState.Notice` 와 같다 — 기기가 네트워크에 닿지 못한 것과
/// 서버까지 갔다가 실패한 것은 사용자가 할 일이 다르다.
enum InviteNotice: Equatable {
    /// 초대가 없거나 만료됐다.
    case expired
    /// 개인방이라 합류할 수 없다.
    case notAllowed
    /// 네트워크에 닿지 못해 초대를 확인하지 못했다. **초대가 무효라는 뜻이 아니다.**
    case connectionLost
    /// 그 밖의 실패.
    case temporary
}

/// 앱 최상위 Coordinator. 탭별 flow Coordinator 와 진입 게이트를 소유한다.
@Observable
@MainActor
final class AppCoordinator {
    let home: HomeCoordinator
    let archive: ArchiveCoordinator
    let notification: NotificationCoordinator
    let profile: ProfileCoordinator

    /// 지금 보고 있는 탭. **View 의 `@State` 가 아니라 여기 있다** — 알림에서 저장 탭으로 넘기는
    /// 것처럼 코드가 탭을 바꿔야 하는 경로가 있어서다(딥링크·푸시도 같은 자리를 쓰게 된다).
    ///
    /// `MainTab` 이 아니라 `Int` 인 이유: `MHTabBar` 가 `Binding<Int>` 를 받는다. 여기서 `MainTab`
    /// 으로 들면 뷰마다 변환 Binding 을 손으로 만들어야 한다.
    var selectedTabID: Int = MainTab.home.rawValue

    /// 앱 진입 게이트. 화면 Store 와 달리 **앱 수명과 같아** Coordinator 가 직접 든다 —
    /// 온보딩 완료 보고를 여기로 밀어넣어야 해서 View 의 `@State` 에 둘 수 없다.
    let launch: AppLaunchStore

    /// 확인이 끝나 합류만 남은 초대. `launch` 와 같은 이유로 여기 있다 — 앱 수명과 같은 상태라
    /// 화면의 `@State` 에 두면 진입 게이트가 화면을 갈아끼울 때 함께 버려진다.
    ///
    /// **목적지 값이 아니라 조회 결과를 든다.** 합류 API 가 방 id 를 path 로 받는데 코드에서 그걸
    /// 푸는 수단이 미리보기 조회뿐이라, 코드만 들고 있으면 합류 시점에 왕복이 한 번 더 생긴다.
    private var pendingInvite: PendingInvite?

    /// 초대를 확인·합류하는 중. 그동안 진입 화면(스플래시)을 유지한다 — 아래 `resolveInvite` 참조.
    private(set) var isResolvingInvite = false

    /// 초대 진입 실패 안내. 화면이 갈려도 살아남도록 phase 가 아니라 여기 둔다.
    private(set) var inviteNotice: InviteNotice?
    private var noticeDismissTask: Task<Void, Never>?
    private var acceptTask: Task<Void, Never>?

    /// 지금 확인 중인 초대 코드. 같은 링크가 두 번 도착하는 것을 막는다 — 아래 `resolveInvite` 참조.
    private var resolvingCode: String?

    /// 코드와, 그 코드가 가리키는 방.
    private struct PendingInvite: Equatable {
        let code: String
        let roomID: String
    }

    /// 푸시 토큰을 서버와 맞추는 일. `launch` 와 같은 이유로 여기 있다 — 화면이 아니라 앱 수명이다.
    let pushTokenSync: PushTokenSync

    /// 아직 메인이 아닐 때 도착한 푸시. 콜드런치에서 알림을 누르면 화면은 스플래시고 **탭이 아직
    /// 없다**(`RootView` 가 `.main` 에서만 `MainTabView` 를 만든다). `.main` 에 들어설 때까지 들고
    /// 있다가 그때 소비한다 — 바로 위 `pendingDeeplink` 와 같은 문제·같은 해법이다.
    ///
    /// 온보딩 중이면 온보딩을 마친 뒤에 열린다. 그 사이 앱이 죽어 보관분이 사라지는 건 허용한다 —
    /// 알림은 목록에 그대로 남아 있어 다시 누르면 된다.
    private var pendingPush: NotificationDestination?

    /// 콜드런치로 들어온 푸시의 도착지를 아직 조회 중이다. 참인 동안 `RootView` 는 **스플래시를
    /// 유지한다** — 조회가 끝나기 전에 메인 탭을 그리면 홈 탭이 잠깐 보였다가 저장 탭으로 튄다.
    ///
    /// 이미 메인이 떠 있는 상태(백그라운드 복귀)에서는 켜지 않는다. 보고 있던 화면을 스플래시로
    /// 덮는 게 더 이상하다 — 그 경우엔 보던 탭에 머물다 조회가 끝나면 옮겨 간다.
    private(set) var isResolvingPush = false

    /// 자식 flow 를 만들 때마다 넘겨야 해서 보관한다 — 온보딩은 flow 1회당 새로 만든다.
    private let deps: AppDependencies

    init(deps: AppDependencies) {
        self.deps = deps
        self.pushTokenSync = deps.pushTokenSync
        self.home = HomeCoordinator(deps: deps)
        self.archive = ArchiveCoordinator(deps: deps)
        self.notification = NotificationCoordinator(deps: deps)
        self.profile = ProfileCoordinator(deps: deps)
        self.launch = AppLaunchStore(
            AppLaunchState(),
            reduce: appLaunchReducer(ensureSession: deps.ensureSession, fetchProfile: deps.fetchProfile)
        )
        // navigation 채널이 없는 flow 라(Nav == Never) observeNavigation 을 붙이지 않는다.

        // 알림 탭이 탭 밖으로 내보내는 이동을 여기서 받는다. 자식이 부모를 알지 못하게
        // 콜백으로만 잇는다(retain cycle 방지: weak).
        notification.onCrossTab = { [weak self] destination in
            switch destination {
            case .place(let pin, let room): self?.open(.place(pin: pin, room: room))
            case .room(let room): self?.open(.room(room))
            }
        }
    }

    /// 탭 밖에서 들어오는 이동의 **유일한 진입점**. 알림이 첫 소비자이고, 딥링크·푸시가 붙을 때도
    /// 같은 함수를 부른다 — 경로마다 진입점을 쪼개면 탭 전환 규칙이 그만큼 갈라진다.
    ///
    /// **동기여야 한다.** `archive.open` 이 서는 순간 저장 탭이 탭바를 감추는 화면이 되는데
    /// (`ArchiveCoordinator.isFullBleedContentPresented`), 여기에 `await` 가 끼면 아직 알림 탭인 채로
    /// 탭바만 사라지는 프레임이 생긴다. 그래서 조회는 부르는 쪽이 끝내고 객체를 넘긴다.
    func open(_ destination: AppDestination) {
        switch destination {
        case .place(let pin, let room): archive.open(pin: pin, in: room)
        case .room(let room): archive.open(room: room)
        }
        selectedTabID = MainTab.save.rawValue
    }

    /// 푸시를 눌렀을 때의 진입점. 메인이 아직 아니면 들고 있다가 `mainDidAppear()` 가 소비한다.
    func handle(push destination: NotificationDestination) {
        guard launch.state.phase == .main else {
            pendingPush = destination
            // 메인이 그려지기 **전에** 켜 둔다 — `.main` 에 들어서는 순간 스플래시가 이어지고
            // 메인 탭은 도착지가 정해진 뒤에 한 번만 그려진다.
            isResolvingPush = true
            return
        }
        resolve(destination)
    }

    /// 메인 진입 시점(`RootView`)에 부른다. 스플래시를 유지하는 동안에도 불려야 해서
    /// `MainTabView` 가 아니라 `.main` 분기 자체에 걸린다 — 아니면 보관분을 꺼낼 사람이 없다.
    func mainDidAppear() {
        pushTokenSync.kick()
        guard let destination = pendingPush else { return }
        pendingPush = nil
        resolve(destination)
    }

    /// 포그라운드 복귀. 토큰 업로드의 사실상 재시도 지점이다 — 별도 재시도 타이머를 두지 않는 근거다.
    func didBecomeActive() {
        guard launch.state.phase == .main else { return }
        pushTokenSync.kick()
    }

    /// 알림이 가리키는 곳을 열어 준다.
    ///
    /// `open(_:)` 이 완성된 `Pin`·`Room` 을 요구해서(동기여야 하는 이유는 그쪽 주석) 여기서 조회를
    /// 끝내고 넘긴다 — 알림 셀 탭(`NotificationListStore`)이 하는 것과 같은 흐름이다.
    private func resolve(_ destination: NotificationDestination) {
        switch destination {
        case .place(let pinID):
            Task { [weak self] in
                guard let self else { return }
                do {
                    let pin = try await deps.fetchPinDetail.execute(pinID: pinID).pin
                    // 열 방은 알림이 아니라 핀이 정한다(FR-022).
                    let room = try await deps.fetchRoom.execute(id: pin.roomID)
                    finishPush { $0.open(.place(pin: pin, room: room)) }
                } catch {
                    finishPush { $0.landOnNotificationTab() }
                }
            }
        case .room(let roomID):
            Task { [weak self] in
                guard let self else { return }
                do {
                    let room = try await deps.fetchRoom.execute(id: roomID)
                    finishPush { $0.open(.room(room)) }
                } catch {
                    finishPush { $0.landOnNotificationTab() }
                }
            }
        // 저장 오류 안내는 알림 탭 안의 화면이다(EC-013). 목록에 그 알림이 있으니 탭까지만 보내면
        // 사용자가 눌러 들어갈 수 있다 — 밖에서 그 화면을 직접 여는 진입점은 아직 없다.
        case .saveError, .unresolved:
            finishPush { $0.landOnNotificationTab() }
        }
    }

    /// 도착지가 정해졌다 — 이동하고 스플래시를 내린다. **순서가 중요하다**: 먼저 이동해 두지
    /// 않으면 메인 탭이 한 프레임 동안 홈으로 그려진 뒤 옮겨 간다.
    private func finishPush(_ move: (AppCoordinator) -> Void) {
        move(self)
        isResolvingPush = false
    }

    private func landOnNotificationTab() {
        selectedTabID = MainTab.notification.rawValue
    }

    /// 온보딩 화면에 들어설 때 호출한다. **flow 1회당 새 인스턴스를 만든다** —
    /// 완주한 인스턴스를 재사용하면 마지막 화면부터 뜨고 `finish` 도 다시 발사되지 않는다
    /// (`OnboardingCoordinator` 타입 주석). 인스턴스는 화면(`OnboardingHost`)이 소유하고,
    /// `.main` 으로 넘어가면 그 화면과 함께 버려진다.
    func makeOnboarding() -> OnboardingCoordinator {
        // 보관분을 **꺼내지 않고 본다** — 방 id 를 합류할 때까지 들고 있어야 한다.
        let child = OnboardingCoordinator(deps: deps, inviteCode: pendingInvite?.code)
        child.finish.bind { [weak self] result in
            guard let self else { return }
            switch result {
            case .completed:
                break
            // 합류는 유저 등록 뒤에만 된다(서버가 미등록을 401 로 막는다). 온보딩을 마친 지금이
            // 첫 기회다. 결과가 실어 온 코드는 쓰지 않는다 — 방 id 가 붙은 보관분이 이미 있다.
            case .completedWithInvite:
                acceptPendingInvite()
            }
            self.launch.send(.onboardingFinished)
        }
        return child
    }

    /// 외부에서 들어온 URL 의 유일한 진입점(`MINOApp` 의 `.onOpenURL`).
    func handle(_ url: URL) {
        guard let deeplink = deps.deeplinkParser.parse(url) else {
            // 파서가 앱의 신뢰 경계다 — 해석되지 않는 링크는 되살리지 않고 버린다.
            // 코드 값은 남기지 않는다(로그로 새는 초대 링크는 그 자체로 방 접근권이다).
            Log.notice("해석하지 못한 딥링크를 버린다", metadata: ["scheme": url.scheme ?? "-"])
            return
        }
        switch deeplink {
        case .invite(let code): resolveInvite(code)
        }
    }

    /// 초대 코드가 가리키는 방을 확인한다. **합류보다 먼저, 진입 화면을 잡아 둔 채로** 한다.
    ///
    /// 초대 유무가 온보딩 경로를 바꾸기 때문이다(공동방 생성·친구초대 스킵). 확인을 미루면
    /// 무효한 코드로 두 스텝을 건너뛴 뒤 **방이 하나도 없는 채로** 온보딩을 마치게 되는데,
    /// 건너뛴 스텝은 되돌릴 수 없다. 그래서 `isResolvingInvite` 로 진입 화면을 붙잡는다 —
    /// 이 조회도 네트워크 왕복이라 세션 판정보다 늦게 끝날 수 있다.
    ///
    /// **같은 코드가 두 번 오면 뒤엣것을 버린다.** `performAccept` 의 "보관분을 먼저 비우는" 방어는
    /// 여기까지 못 온다 — 이 함수가 `performAccept` 를 부르기 직전에 보관분을 **다시 채우기** 때문에,
    /// 두 번 돌면 각자 채운 것을 각자 소비해 합류·조회가 한 벌 더 나가고 두 번째 `open` 이 그 사이
    /// 사용자가 열어 둔 화면을 걷어낸다. 확인이 네트워크 왕복이라 겹칠 창이 넉넉하다(같은 링크를
    /// 다시 탭하는 것으로 재현된다). 다른 코드로 온 새 링크는 막지 않는다 — 그건 나중 것이 이긴다.
    private func resolveInvite(_ code: String) {
        guard resolvingCode != code else { return }
        resolvingCode = code
        isResolvingInvite = true
        Task { [weak self] in
            guard let self else { return }
            defer {
                isResolvingInvite = false
                // 다른 코드가 뒤이어 들어와 자리를 차지했으면 그쪽 것을 지우지 않는다.
                if resolvingCode == code { resolvingCode = nil }
            }
            do {
                let preview = try await deps.fetchInvitationPreview.execute(code: code)
                pendingInvite = PendingInvite(code: code, roomID: preview.roomID)
                Log.info("초대를 확인했다")
                // 온보딩을 이미 마친 사용자는 앱 진입이 곧 초대 수락이다(Flow 6 협의).
                if launch.state.phase == .main { await performAccept() }
            } catch is CancellationError {
                // 취소는 결과가 없어진 것이지 초대가 무효인 게 아니다.
            } catch {
                discardInvite(error)
            }
        }
    }

    /// 화면이 부르는 합류 진입점. 보관 중인 초대가 없으면 아무 일도 하지 않는다.
    ///
    /// **작업을 Coordinator 가 소유한다.** 뷰의 `.task` 에 매달면 합류가 시작되는 순간
    /// `isResolvingInvite` 가 그 뷰를 진입 화면으로 갈아치우고, 사라진 뷰와 함께 요청이 취소돼
    /// 조용히 아무 일도 일어나지 않는다.
    func acceptPendingInvite() {
        guard pendingInvite != nil, acceptTask == nil else { return }
        acceptTask = Task { [weak self] in
            await self?.performAccept()
            self?.acceptTask = nil
        }
    }

    /// 확인된 초대로 방에 합류하고 그 방을 연다.
    ///
    /// 부르는 곳이 셋이라(온보딩 완주 · 진입 시점 `MainTabView` · 이미 `.main` 인 웜 스타트)
    /// **보관분을 먼저 비워** 두 번 도는 것을 막는다. 서버 합류가 멱등이라 겹쳐도 안전하지만
    /// 방 상세가 두 번 열리면 화면이 튄다.
    private func performAccept() async {
        guard let invite = pendingInvite else { return }
        pendingInvite = nil
        isResolvingInvite = true
        defer { isResolvingInvite = false }

        do {
            try await deps.joinRoom.execute(roomID: invite.roomID, inviteCode: invite.code)
            let room = try await deps.fetchRoom.execute(id: invite.roomID)
            Log.info("초대로 방에 합류했다")
            open(.room(room))
        } catch is CancellationError {
        } catch {
            discardInvite(error)
        }
    }

    /// 초대를 없던 것으로 치고 평소 진입으로 보낸다. 실패 이유만 스낵바로 알린다(Flow 6 협의).
    private func discardInvite(_ error: Error) {
        pendingInvite = nil
        let notice = Self.notice(for: error)
        Log.notice("초대를 폐기한다", metadata: ["reason": "\(notice)"])
        showInviteNotice(notice)
    }

    private static func notice(for error: Error) -> InviteNotice {
        switch error as? DomainError {
        case .invitationNotFound: .expired
        case .personalRoomNotAllowed: .notAllowed
        case .networkUnavailable: .connectionLost
        default: .temporary
        }
    }

    /// 잠깐 띄우고 스스로 내린다 — 진입을 막지 않는 안내라 사용자가 닫을 필요가 없다.
    private func showInviteNotice(_ notice: InviteNotice) {
        inviteNotice = notice
        noticeDismissTask?.cancel()
        noticeDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.inviteNotice = nil
        }
    }
}
