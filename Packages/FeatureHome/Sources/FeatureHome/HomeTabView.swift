import DesignSystem
import FlowCoordination
import SwiftUI

/// 홈 탭 진입 View. NavigationStack 을 Coordinator 에 바인딩한다.
///
/// 플로팅 "더 보기" 버튼은 NavigationStack **바깥**의 ZStack 에 둔다.
/// NavigationStack 은 상위(MainTabView)의 `safeAreaInset` 탭바 인셋을 자기 콘텐츠엔 전파하지 않고
/// 기기 홈 인디케이터 인셋만 적용한다 — 그래서 버튼을 스택 안(HomeContentView)에 두면 탭바에 가린다.
/// 스택 바깥의 이 ZStack 은 탭바만큼 줄어든 safe area 를 그대로 보므로 버튼이 탭바 위에 뜬다.
public struct HomeTabView: View {
    private let coordinator: HomeCoordinator
    @State private var store: HomeStore?

    public init(coordinator: HomeCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        @Bindable var coordinator = coordinator
        let showMore = store.map(shouldShowMoreButton) ?? false
        ZStack(alignment: .bottom) {
            NavigationStack(path: $coordinator.path) {
                content
            }
            // 애니메이션은 버튼 서브트리에만 건다 — ZStack 전체에 걸면 버튼이 뜨는 순간
            // 같은 트랜잭션에서 바뀐 카드 덱 레이아웃까지 재애니메이션돼 덱이 흔들린다.
            moreButton
                .animation(.easeInOut(duration: 0.3), value: showMore)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let store {
            HomeContentView(store: store)
        } else {
            ProgressView()
                .task { store = coordinator.makeHomeStore() }
        }
    }

    /// 현재 방에 2개 이하 남았을 때 뜨는 플로팅 CTA. 탭바 위(safe area)에 뜨도록 스택 바깥에 배치.
    @ViewBuilder
    private var moreButton: some View {
        if let store, shouldShowMoreButton(store) {
            MHButton(
                "이 방 장소 더 보기",
                variant: .solid,
                color: .primary,
                size: .large,
                leadingIcon: .refresh
            ) {
                store.send(.tapMorePlaces)
            }
            .mhButtonPillShape()
            .padding(.bottom, 20)   // Figma: 버튼 하단↔탭바 상단 간격(698→719 = 21 ≈ lg 20)
            .transition(.opacity)   // 원래 자리에서 페이드인 (아래→위 이동 없음)
            .accessibilityIdentifier("Home.moreButton")
        }
    }

    /// 현재 방에 (현재 카드 포함) 2개 이하 남으면 플로팅 버튼 표시 — 방마다 끝자락에서 뜬다
    private func shouldShowMoreButton(_ store: HomeStore) -> Bool {
        !store.state.pins.isEmpty && store.state.remainingInCurrentRoom <= 2
    }
}
