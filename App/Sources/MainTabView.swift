import DesignSystem
import FeatureArchive
import FeatureHome
import SwiftUI

/// 메인 탭 종류
enum MainTab: CaseIterable {
    case home
    case save

    var title: String {
        switch self {
        case .home: "홈"
        case .save: "저장"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .home: "MainTab.tab.home"
        case .save: "MainTab.tab.save"
        }
    }
}

/// 앱 루트 탭 화면. 홈/저장 탭 콘텐츠와 커스텀 탭바를 담는다.
/// 탭바는 safeAreaInset 으로 붙여 콘텐츠가 기본으로 탭바에 가리지 않는다.
/// 탭바 뒤까지 깔려야 하는 화면(지도 등)은 그 화면에서 ignoresSafeArea 로 opt-in 한다.
/// 탭 아이콘 이미지는 추후 삽입 — 지금은 영역(24pt)만 표시한다.
struct MainTabView: View {
    private let coordinator: AppCoordinator
    @State private var selectedTab: MainTab = .home

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
    }

    @ViewBuilder private var content: some View {
        switch selectedTab {
        case .home: HomeTabView(coordinator: coordinator.home)
        case .save: ArchiveTabView(coordinator: coordinator.archive)
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                tabItem(tab)
            }
        }
        .padding(.top, 10)   // Figma: Content py 8 + Container pt 2
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background {
            // Figma: Background/Normal/Normal 88% + backdrop blur
            Color.mhBackgroundNormalNormal.opacity(0.88)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.mhLineNormalNeutral)
                .frame(height: 0.5)
        }
    }

    private func tabItem(_ tab: MainTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 2) {
                // 아이콘 자리 — 이미지 추후 삽입
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? .mhPrimaryNormal : .mhInteractionInactive)
                    .frame(width: 24, height: 24)
                Text(tab.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .mhPrimaryNormal : .mhInteractionInactive)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tab.accessibilityIdentifier)
    }
}

// MARK: - Preview

#Preview {
    MainTabView(coordinator: AppCoordinator(deps: AppDependencies()))
}
