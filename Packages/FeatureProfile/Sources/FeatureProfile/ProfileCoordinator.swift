import Domain
import FlowCoordination
import MVI
import ProfileSetupUI
import SwiftUI

/// 마이 탭 flow. 프로필 요약의 연필을 누르면 프로필 설정 화면이 push 된다(FR-002).
///
/// 연관값이 없다 — 설정 화면이 `edit` 모드로 진입하며 스스로 조회해 채운다(``ProfileMainNav``).
public enum ProfileRoute: Hashable {
    case profileSetup
}

/// 탭 flow 는 앱 생존 내내 유지되므로 종료가 없다 — Output = Never.
@Observable
@MainActor
public final class ProfileCoordinator: Coordinator {
    public var path: [ProfileRoute] = []
    public var sheet: Never?
    public var cover: Never?
    public let finish = FlowFinish<Never>()

    /// 떠 있는 안내 다이얼로그 — **루트(`MainTabView`)가 그린다.**
    ///
    /// 딤이 탭바까지 덮어야 하는데 탭바는 루트가 탭 콘텐츠 위에 얹으므로, 탭 콘텐츠 안에서
    /// 그리면 탭바만 밝게 남는다. 그래서 z-order 를 쥔 루트로 올린다
    /// (`HomeCoordinator.isGuidePresented` 가 같은 이유로 존재한다).
    ///
    /// Store 를 여기서 만들어 읽는다 — `state` 를 읽는 순간 관찰이 걸려 다이얼로그가 뜨고 질 때
    /// 루트가 다시 그려진다. 호출부가 마이 탭일 때만 보므로 다른 탭에서 Store 가 생기지 않는다.
    public var presentedDialog: ProfileMainDialog? {
        profileMainStore().state.dialog
    }

    /// 안내의 취소 — 루트에서 그리는 다이얼로그가 상태를 닫도록 위임받는다.
    public func dismissDialog() {
        profileMainStore().send(.dismissDialog)
    }

    /// 안내의 확인 — 세 경우 모두 OS 설정 앱으로 보낸다.
    public func confirmDialog() {
        profileMainStore().send(.confirmDialog)
    }

    /// 탭바 자체를 레이아웃에서 빼야 하는 전체화면 상태인가 — MainTabView 가 본다.
    /// 프로필 설정은 자체 상단바와 하단 액션 영역을 가진 전체화면이라(디자인 010-2 에 탭바가 없다)
    /// 탭바를 두면 저장·지우기 버튼이 그 아래로 깔린다(`ArchiveCoordinator` 선례).
    public var isFullBleedContentPresented: Bool {
        !path.isEmpty
    }

    private let deps: ProfileDeps

    public init(deps: ProfileDeps) {
        self.deps = deps
    }

    // MARK: - Store Factory

    /// 마이페이지 Store. **탭 flow 인 Coordinator 가 들고 있어 탭을 오갈 때 살아남는다.**
    ///
    /// `MainTabView` 는 선택된 탭만 그리는 `switch` 라, 화면(View)이 `@State` 로 들면 탭을 떠나는
    /// 순간 폐기된다 — 돌아올 때마다 빈 상태부터 다시 그려져 조회 왕복이 그대로 체감된다.
    /// 여기 두면 돌아온 화면이 **직전 값 그대로** 뜨고, 재조회는 그 위에서 조용히 끝난다.
    ///
    /// 스위치 표시값은 여기 남지 않는다 — 진입·복귀마다 OS 에서 다시 읽는다(FR-009).
    /// Store 에 남는 건 마지막으로 읽은 **결과**이고, 그 위를 새 조회가 곧 덮는다.
    ///
    /// `@ObservationIgnored`: body 평가 중에 채워지는 자리라 관찰 대상이 되면 "뷰 업데이트 중 상태
    /// 변경" 이 된다. 한 번 만들면 바뀌지 않으므로 관찰할 것도 없다.
    @ObservationIgnored private var mainStore: ProfileMainStore?

    func profileMainStore() -> ProfileMainStore {
        if let mainStore { return mainStore }
        let store = ProfileMainStore(
            // 서버를 기다리지 않고 아는 값으로 먼저 그린다 — 이번 실행에서 이미 한 번 읽었다면
            // (앱 시작이 온보딩 여부를 판단하며 읽는다) 첫 프레임부터 이름·아바타가 채워져 있다.
            ProfileMainState(profile: deps.lastKnownProfile.execute()),
            reduce: profileMainReducer(
                fetchProfile: deps.fetchProfile,
                notification: deps.notificationSetting,
                location: deps.locationSetting
            ),
            handle: { [weak self] in self?.handle($0) }
        )
        mainStore = store
        return store
    }

    /// 마이페이지 진입점은 **수정**이다 — 진입하면서 조회해 채우고, 저장은 `PATCH /users/me`.
    /// `ProfileSetupUI` 가 목적과 UseCase 를 한 값(`.edit`)으로 묶어 줘서 조합이 어긋날 수 없다.
    func makeProfileSetupStore() -> ProfileSetupStore {
        ProfileSetupUI.makeProfileSetupStore(
            .edit(fetch: deps.fetchProfile, update: deps.updateProfile),
            handle: { [weak self] in self?.handle($0) }
        )
    }

    // MARK: - Navigation Routing

    func handle(_ nav: ProfileMainNav) {
        switch nav {
        case .pushProfileSetup:
            push(.profileSetup)
        case .openURL(let url):
            openURL(url)
        case .openSystemSettings:
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        }
    }

    /// 저장이 끝나면 마이페이지로 돌아간다. 갱신된 값(FR-003 — 저장 완료 시 즉시 반영)은
    /// 되돌아온 화면이 다시 읽는다 — 재조회 지점이 하나뿐이라 여기서 값을 들고 오지 않는다.
    /// (수정 유스케이스가 ``LastKnownProfileUseCase`` 도 갱신해 두어 첫 프레임부터 새 값이다)
    func handle(_ nav: ProfileSetupNav) {
        switch nav {
        case .didSave:
            pop()
        }
    }

    // 화면(View)이 아니라 여기서 연다 — 라우팅은 Coordinator 몫이고, 그래야 테스트가 nav 를 직접 검증한다.
    private func openURL(_ url: URL) {
        UIApplication.shared.open(url)
    }
}
