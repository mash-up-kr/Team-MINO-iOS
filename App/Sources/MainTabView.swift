import DesignSystem
import FeatureArchive
import FeatureHome
import FeatureNotification
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

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    private var selectedTab: MainTab {
        MainTab(rawValue: coordinator.selectedTabID) ?? .home
    }

    /// 홈에서 딤을 직접 까는 시트(방 리스트 · 게시물 저장)가 떠 있는가.
    /// 그 딤은 탭바보다 아래 레이어라 탭바가 밝게 남으므로, 탭바를 투명하게 만들어 뒤의 딤이 비치게 한다.
    private var isHomeDimmedSheetPresented: Bool {
        coordinator.home.isRoomListPresented || coordinator.home.isSavePostPresented
    }

    /// 탭바 없이 화면 바닥까지 깔려야 하는 화면(방 상세 바텀시트 · 공동방 만들기 등)이 떠 있는가.
    private var isFullBleedContentPresented: Bool {
        coordinator.archive.isFullBleedContentPresented
            || coordinator.home.isFullBleedContentPresented
            || coordinator.profile.isFullBleedContentPresented
    }

    var body: some View {
        @Bindable var coordinator = coordinator
        return content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !isFullBleedContentPresented {
                    // 방 리스트 시트가 뜨면 탭바를 자리에 둔 채 페이드아웃(제거하지 않음 → reflow·깜빡임 없음).
                    // 탭바가 투명해지면 그 뒤에 깔린 홈 콘텐츠 딤(ignoresSafeArea)이 비쳐 탭바 자리도 딤 처리된다.
                    MHTabBar(
                        items: MainTab.allCases.map(\.tabBarItem),
                        selectedID: $coordinator.selectedTabID
                    )
                    .opacity(isHomeDimmedSheetPresented ? 0 : 1)
                    .allowsHitTesting(!isHomeDimmedSheetPresented)
                    // 딤은 시트가 뜨는 순간 빠르게 걸리고(0.1), 닫힐 땐 기존 속도로 풀린다(0.3).
                    // 닫힘까지 빠르게 하면 탭바가 시트보다 먼저 복귀해 깜빡일 수 있어 켜지는 쪽만 앞당긴다.
                    .animation(
                        isHomeDimmedSheetPresented
                            ? .easeOut(duration: 0.1)
                            : .easeInOut(duration: 0.3),
                        value: isHomeDimmedSheetPresented
                    )
                }
            }
            // 홈 사용 가이드의 "시작하기" CTA 는 탭바 자리를 통째로 덮어야 해서(시안) 탭 콘텐츠 안이
            // 아니라 여기(루트)에서 그린다. 딤은 홈이 요소별로 걸고, 루트는 z-order 만 책임진다.
            .overlay {
                if selectedTab == .home, coordinator.home.isGuidePresented {
                    HomeGuideOverlay(onStart: { coordinator.home.dismissGuide() })
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: coordinator.home.isGuidePresented)
    }

    @ViewBuilder private var content: some View {
        switch selectedTab {
        case .home: HomeTabView(coordinator: coordinator.home)
        case .save: ArchiveTabView(coordinator: coordinator.archive)
        case .notification: NotificationTabView(coordinator: coordinator.notification)
        case .profile: ProfileTabView(coordinator: coordinator.profile)
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView(coordinator: AppCoordinator(deps: AppDependencies()))
}
