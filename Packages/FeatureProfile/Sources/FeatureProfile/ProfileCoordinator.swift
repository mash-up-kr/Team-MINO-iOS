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

    func makeProfileMainStore() -> ProfileMainStore {
        Store(
            ProfileMainState(),
            reduce: profileMainReducer(
                fetchProfile: deps.fetchProfile,
                notification: deps.notificationSetting,
                location: deps.locationSetting
            ),
            handle: { [weak self] in self?.handle($0) }
        )
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

    /// 저장이 끝나면 마이페이지로 돌아간다(FR-003). 갱신된 값은 되돌아온 화면이 다시 읽는다
    /// — 재조회 지점이 하나뿐이라(FR-009) 여기서 값을 들고 오지 않는다.
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
