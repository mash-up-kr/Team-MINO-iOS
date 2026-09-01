import Domain
import Feature
import FeatureArchive
import FeatureHome
import FeatureNotification
import FeatureOnboarding
import FeatureProfile
import SwiftUI

/// 탭 밖에서 들어오는 이동의 도착지. **장소·방 모두 저장 탭에서 연다** — 홈 탭도 같은 장소 상세를
/// 열 수 있지만, 저장 탭이 방 상세와 장소 상세를 모두 갖고 있어 한 곳으로 모은다.
enum AppDestination: Equatable {
    case place(pin: Pin, room: Room)
    case room(Room)
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

    /// 자식 flow 를 만들 때마다 넘겨야 해서 보관한다 — 온보딩은 flow 1회당 새로 만든다.
    private let deps: AppDependencies

    init(deps: AppDependencies) {
        self.deps = deps
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

    /// 온보딩 화면에 들어설 때 호출한다. **flow 1회당 새 인스턴스를 만든다** —
    /// 완주한 인스턴스를 재사용하면 마지막 화면부터 뜨고 `finish` 도 다시 발사되지 않는다
    /// (`OnboardingCoordinator` 타입 주석). 인스턴스는 화면(`OnboardingHost`)이 소유하고,
    /// `.main` 으로 넘어가면 그 화면과 함께 버려진다.
    func makeOnboarding() -> OnboardingCoordinator {
        let child = OnboardingCoordinator(deps: deps)
        child.finish.bind { [weak self] result in
            switch result {
            // 초대 착지는 딥링크 배선이 붙을 때 처리한다 — 지금은 방을 열 화면이 없다.
            // case 를 나열해 둬 결과가 늘면 컴파일이 여기서 깨진다.
            case .completed, .completedWithInvite:
                break
            }
            self?.launch.send(.onboardingFinished)
        }
        return child
    }
}
