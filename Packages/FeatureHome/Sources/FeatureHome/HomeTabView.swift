import DesignSystem
import FlowCoordination
import RoomCreationUI
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
        let showMore = (store.map(shouldShowMoreButton) ?? false) && coordinator.path.isEmpty
        ZStack(alignment: .bottom) {
            NavigationStack(path: $coordinator.path) {
                content
                    .navigationDestination(for: HomeRoute.self) { route in
                        switch route {
                        case .createRoom:
                            // 방 리스트 시트에서 진입 → 건너뛰기 없음(showsSkip: false)
                            // CreateRoomView 가 내비바를 숨겨 엣지 백스와이프가 꺼지므로 되살린다.
                            CreateRoomView(makeStore: coordinator.makeCreateRoomStore, showsSkip: false)
                                .enablesBackSwipe()
                        }
                    }
            }
            // 애니메이션은 버튼 서브트리에만 건다 — ZStack 전체에 걸면 버튼이 뜨는 순간
            // 같은 트랜잭션에서 바뀐 카드 덱 레이아웃까지 재애니메이션돼 덱이 흔들린다.
            moreButton
                .animation(.easeInOut(duration: 0.3), value: showMore)
            savedToast
        }
        .animation(.easeInOut(duration: 0.2), value: store?.state.savedToastID)
    }

    /// 저장 완료 스낵바 (Figma `013-2`). 플로팅 버튼과 같은 이유로 NavigationStack **바깥**에 둔다 —
    /// 안에 두면 탭바에 가린다. 노출 2초 뒤 스스로 사라진다.
    @ViewBuilder
    private var savedToast: some View {
        if let store, let toastID = store.state.savedToastID {
            MHSnackbar(title: "저장이 완료됐습니다.", icon: .checkThick)
                .padding(.horizontal, 20)
                // 시안(013-2, node 2862:178010)의 "화면 바닥에서 40" 을 탭바 위로 옮긴 값 —
                // 시안 프레임에는 탭바가 없어 그대로 40 을 주면 탭바에 겹친다.
                .padding(.bottom, 40)
                .allowsHitTesting(false)   // 장식 — 뒤의 카드 덱 스와이프를 가리지 않는다
                .transition(.opacity)
                .accessibilityIdentifier("Home.savedToast")
                .task(id: toastID) {
                    // 취소를 삼키면 안 된다. try? 로 받으면 새 토스트가 이 task 를 취소했을 때
                    // sleep 이 즉시 반환하고, 이어지는 dismiss 가 **방금 뜬 토스트**를 지운다.
                    do { try await Task.sleep(for: .seconds(2)) } catch { return }
                    store.send(.dismissSavedToast(toastID))
                }
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
        if let store, coordinator.path.isEmpty, shouldShowMoreButton(store) {
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

    /// 현재 방에 (현재 카드 포함) 2개 이하 남으면 플로팅 버튼 표시 — 방마다 끝자락에서 뜬다.
    /// 전 방 소진 화면에는 CTA 를 두지 않는다(기획 결정) — 그때는 remainingInCurrentRoom 도 0 이라
    /// 소진 여부를 함께 보지 않으면 "이 방 장소 더 보기"가 소진 화면에 딸려 나온다.
    private func shouldShowMoreButton(_ store: HomeStore) -> Bool {
        let state = store.state
        return !state.pins.isEmpty && !state.hasViewedAllPlaces && state.remainingInCurrentRoom <= 2
    }
}
