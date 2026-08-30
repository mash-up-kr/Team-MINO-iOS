import DesignSystem
import Domain
import FlowCoordination
import PlaceDetailUI
import RoomCreationUI
import SwiftUI

/// 홈 탭 진입 View. NavigationStack 을 Coordinator 에 바인딩한다.
///
/// 저장 완료 스낵바는 NavigationStack **바깥**의 ZStack 에 둔다.
/// NavigationStack 은 상위(MainTabView)의 `safeAreaInset` 탭바 인셋을 자기 콘텐츠엔 전파하지 않고
/// 기기 홈 인디케이터 인셋만 적용한다 — 그래서 스택 안(HomeContentView)에 두면 탭바에 가린다.
/// 스택 바깥의 이 ZStack 은 탭바만큼 줄어든 safe area 를 그대로 보므로 탭바 위에 뜬다.
public struct HomeTabView: View {
    private let coordinator: HomeCoordinator
    @State private var store: HomeStore?
    /// 장소 상세 시트의 단계. 정책상 진입은 항상 half(= `.medium`)다 —
    /// 002-1 ③ "카드 클릭 시 005-1 half(Default)로 이동".
    @State private var placeDetailDetent: MHBottomSheetDetent = .medium

    public init(coordinator: HomeCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        @Bindable var coordinator = coordinator
        ZStack(alignment: .bottom) {
            NavigationStack(path: $coordinator.path) {
                content
                    .navigationDestination(for: HomeRoute.self) { route in
                        switch route {
                        case .createRoom:
                            // 방 리스트 시트에서 진입 → 건너뛰기 없음(showsSkip: false)
                            // RoomFormView 가 내비바를 숨겨 엣지 백스와이프가 꺼지므로 되살린다.
                            RoomFormView(makeStore: coordinator.makeRoomFormStore, showsSkip: false)
                                .enablesBackSwipe()
                        }
                    }
            }
            placeDetailSheet
            savedToast
        }
        .animation(.easeInOut(duration: 0.2), value: store?.state.savedToastID)
        .animation(.spring(duration: 0.35), value: coordinator.selectedPin?.id)
    }

    /// 카드 탭으로 열리는 장소 상세 — **홈 위에 얹히는 half 바텀시트**다
    /// (002-1 ③ "카드 클릭 시 005-1 half(Default)로 이동", 카드덱 spec §3.2 `[SCR-006] 장소 상세 Half`).
    ///
    /// 저장 탭(``ArchiveShellView``)과 같은 ``MHBottomSheet`` · 같은 half 노출 높이(005-1 ⑫ 335)를 쓴다 —
    /// ``PlaceDetailHeader`` 의 상단 여백이 "시트 그래버가 30pt 를 채운다"는 전제로 잡혀 있어, 시스템
    /// 시트로 띄우면 half 에서 헤더가 시트 윗끝에 붙는다.
    ///
    /// 시트를 닫아도 홈은 그대로 살아 있다(같은 뷰 트리에 겹쳐 그릴 뿐이라 `HomeContentView` 가
    /// 사라지지 않는다) → 조회를 다시 하지 않고 보던 카드·커서가 유지된다. 홈이 다시 조회하는 건
    /// 탭을 오갈 때뿐이다(`MainTabView` 가 탭마다 화면을 새로 만든다).
    ///
    /// 딤은 두지 않는다 — half 는 뒤의 덱을 보여 주는 단계이고, 005-1 도 뒤 화면을 가리지 않는다.
    @ViewBuilder
    private var placeDetailSheet: some View {
        if let pin = coordinator.selectedPin {
            MHBottomSheet(
                detent: $placeDetailDetent,
                // 005-1 ⑫ 의 half 노출 높이 335. 탭바가 시트를 아래에서 덮으므로 그만큼 더 그려
                // 335 가 탭바 **위로** 온전히 보이게 한다(저장 탭의 `tabBarCoverage` 와 같은 보정).
                mediumPeek: 335,
                bottomCoverage: MHTabBar.height,
                detents: [.medium, .full]   // 장소 상세는 low 를 쓰지 않는다(저장 탭과 동일)
            ) {
                HomePlaceDetailView(coordinator: coordinator, pin: pin, detent: placeDetailDetent)
            }
            .transition(.move(edge: .bottom))
            // 다음에 열 때는 다시 half 로 시작한다(진입 단계는 정책이 half 로 고정).
            .onDisappear { placeDetailDetent = .medium }
            .accessibilityIdentifier("Home.placeDetail.sheet")
        }
    }

    /// 저장 완료 스낵바 (Figma `013-2`). 위 주석과 같은 이유로 NavigationStack **바깥**에 둔다 —
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
}

/// 시트 안의 장소 상세. Store 를 `.task` 에서 1회 만든다 — 시트 content 클로저는 body 재평가마다
/// 다시 불리므로 여기서 바로 만들면 그때마다 Store 가 새로 나 조회가 반복된다.
private struct HomePlaceDetailView: View {
    let coordinator: HomeCoordinator
    let pin: Pin
    /// 시트 단계 — 헤더 상단 여백이 단계마다 다르다(``PlaceDetailHeaderMetrics``).
    let detent: MHBottomSheetDetent

    @State private var store: PlaceDetailStore?

    var body: some View {
        Group {
            if let store {
                PlaceDetailView(store: store, detent: detent)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // 핀이 바뀌면 그 핀의 Store 로 갈아끼운다 — 시트가 살아 있는 채로 다른 카드를
                    // 열 일은 없지만, 열려 있는 동안 pin 만 바뀌면 옛 장소가 남는다.
                    .task(id: pin.id) { store = coordinator.makePlaceDetailStore(pin: pin) }
            }
        }
    }
}
