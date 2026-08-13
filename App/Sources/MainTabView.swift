import DesignSystem
import FeatureArchive
import FeatureHome
import FeatureProfile
import SwiftUI

/// 메인 탭 종류
enum MainTab: Int, CaseIterable {
    case home = 0
    case save = 1
    case notification = 2
    case profile = 3

    var tabBarItem: MHTabBarItem {
        switch self {
        case .home: MHTabBarItem(id: rawValue, icon: .homeFill, label: "홈")
        case .save: MHTabBarItem(id: rawValue, icon: .folderFill, label: "저장")
        case .notification: MHTabBarItem(id: rawValue, icon: .bellFill, label: "알림")
        case .profile: MHTabBarItem(id: rawValue, icon: .personCircleFill, label: "마이페이지")
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .home: "MainTab.tab.home"
        case .save: "MainTab.tab.save"
        case .notification: "MainTab.tab.notification"
        case .profile: "MainTab.tab.profile"
        }
    }
}

/// 앱 루트 탭 화면. 홈/저장/알림/마이페이지 탭 콘텐츠와 MHTabBar 를 담는다.
/// 탭바는 safeAreaInset 으로 붙여 콘텐츠가 기본으로 탭바에 가리지 않는다.
struct MainTabView: View {
    private let coordinator: AppCoordinator
    @State private var selectedTabID: Int = MainTab.home.rawValue

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    private var selectedTab: MainTab {
        MainTab(rawValue: selectedTabID) ?? .home
    }

    /// 탭바 없이 화면 바닥까지 깔려야 하는 화면(방 상세 바텀시트 · 공동방 만들기 등)이 떠 있는가.
    private var isFullBleedContentPresented: Bool {
        coordinator.profile.isRoomDetailPresented
            || coordinator.home.isFullBleedContentPresented
    }

    var body: some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !isFullBleedContentPresented {
                    // 방 리스트 시트가 뜨면 탭바를 자리에 둔 채 페이드아웃(제거하지 않음 → reflow·깜빡임 없음).
                    // 탭바가 투명해지면 그 뒤에 깔린 홈 콘텐츠 딤(ignoresSafeArea)이 비쳐 탭바 자리도 딤 처리된다.
                    MHTabBar(
                        items: MainTab.allCases.map(\.tabBarItem),
                        selectedID: $selectedTabID
                    )
                    .opacity(coordinator.home.isRoomListPresented ? 0 : 1)
                    .allowsHitTesting(!coordinator.home.isRoomListPresented)
                    // 딤은 시트가 뜨는 순간 빠르게 걸리고(0.1), 닫힐 땐 기존 속도로 풀린다(0.3).
                    // 닫힘까지 빠르게 하면 탭바가 시트보다 먼저 복귀해 깜빡일 수 있어 켜지는 쪽만 앞당긴다.
                    .animation(
                        coordinator.home.isRoomListPresented
                            ? .easeOut(duration: 0.1)
                            : .easeInOut(duration: 0.3),
                        value: coordinator.home.isRoomListPresented
                    )
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch selectedTab {
        case .home: HomeTabView(coordinator: coordinator.home)
        case .save: ArchiveTabView(coordinator: coordinator.archive)
        case .notification: notificationPlaceholder
        case .profile: ProfileTabView(coordinator: coordinator.profile)
        }
    }

    /// 알림 탭 — 피쳐 모듈 생기기 전까지 빈 화면
    private var notificationPlaceholder: some View {
        VStack {
            Spacer()
            Text("알림")
                .mhTypography(.body1NormalMedium)
                .foregroundStyle(.mhLabelAlternative)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.mhBackgroundNormalNormal)
    }
}

// MARK: - Preview

#Preview {
    MainTabView(coordinator: AppCoordinator(deps: AppDependencies()))
}
