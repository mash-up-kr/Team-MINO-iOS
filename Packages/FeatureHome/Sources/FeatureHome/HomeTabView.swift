import DesignSystem
import Domain
import FlowCoordination
import PlaceDetailUI
import PlaceMapUI
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
            placeDetailMap
            mapButtons
            placeDetailSheet
            savedToast
        }
        .animation(.easeInOut(duration: 0.2), value: store?.state.savedToastID)
        .animation(.spring(duration: 0.35), value: coordinator.selectedPin?.id)
    }

    /// 장소 상세 뒤에 깔리는 지도 (005-1 과 같은 그림). 카드 덱은 이 **아래에 그대로 살아 있어**
    /// 시트를 닫으면 보던 카드·커서가 그대로 돌아온다 — 조회를 다시 하지 않는다.
    @ViewBuilder
    private var placeDetailMap: some View {
        if let pin = coordinator.selectedPin {
            PlaceMapLayer(
                bottomInset: mapBottomInset,
                pins: [pin],
                myLocation: coordinator.mapFocus?.coordinate,
                roomColor: store?.state.currentRoom?.color,
                selectedPinID: pin.id.value,
                // 마커가 하나뿐이라 갈아탈 곳이 없다 — 눌러도 지금 보고 있는 그 장소다.
                onSelectPin: { _ in },
                // 홈은 탭한 장소 한 곳만 그리므로 맞출 범위가 없다 → 고정 줌으로 가운데 둔다.
                cameraMode: .centered(pin.place.coordinate)
            )
            .transition(.opacity)
        }
    }

    /// 지도 위 현위치 버튼(005-1). 자리 값은 저장 탭과 같은 ``PlaceMapButtonMetrics`` 를 쓴다.
    ///
    /// '저장된 방'(005-1 ⑮)은 띄우지 않는다 — 저장 탭에서 그 버튼은 보고 있는 방을 갈아타는데,
    /// 홈에서 같은 일을 하면 카드 덱이 재조회된다. 무엇을 해야 할지 미정이라 버튼을 내지 않는다
    /// (``HomeCoordinator`` 의 `openSavedRooms` TODO).
    @ViewBuilder
    private var mapButtons: some View {
        if coordinator.selectedPin != nil, let placeStore = coordinator.placeDetailStore {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    MyLocationButton { placeStore.send(.tapMyLocation) }
                }
                .padding(.trailing, PlaceMapButtonMetrics.trailing)
                // 시트 윗끝에서 18 — 저장 탭의 버튼 줄과 같은 계산이다.
                .padding(.bottom, visiblePeek + tabBarCoverage + PlaceMapButtonMetrics.bottomGap)
            }
        }
    }

    /// 005-1 ⑫ 의 half 노출 높이. 저장 탭 장소 상세와 같은 값이다(``ArchiveShellView`` 의 `peek`).
    private static let placeDetailPeek: CGFloat = 335

    /// 지금 단계에서 시트가 드러낸 높이. full 은 지도를 다 덮어 0 이다.
    private var visiblePeek: CGFloat {
        placeDetailDetent == .full ? 0 : Self.placeDetailPeek
    }

    /// 시트를 아래에서 덮는 탭바의 높이.
    ///
    /// 장소 상세가 열리면 `MainTabView` 가 탭바를 레이아웃에서 빼므로
    /// (``HomeCoordinator/isFullBleedContentPresented``) 덮는 게 없어 0 이다 — 탭바를 넣고 빼는
    /// 조건과 **같은 값**을 봐서 이중 보정이 생기지 않는다(저장 탭의 `tabBarCoverage` 와 같다).
    private var tabBarCoverage: CGFloat {
        coordinator.isFullBleedContentPresented ? 0 : MHTabBar.height
    }

    /// 시트가 지도를 가리는 높이. 구글 로고·저작권 표시가 이 위로 밀려 올라간다 —
    /// Google Maps Platform 약관이 attribution 가림을 금지한다.
    private var mapBottomInset: CGFloat {
        placeDetailDetent == .full ? 0 : visiblePeek + tabBarCoverage
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
    /// 딤은 두지 않는다 — half 는 뒤의 지도를 보여 주는 단계이고, 005-1 도 뒤 화면을 가리지 않는다.
    @ViewBuilder
    private var placeDetailSheet: some View {
        if coordinator.selectedPin != nil {
            MHBottomSheet(
                detent: $placeDetailDetent,
                mediumPeek: Self.placeDetailPeek,
                bottomCoverage: tabBarCoverage,
                detents: [.medium, .full],   // 장소 상세는 low 를 쓰지 않는다(저장 탭과 동일)
                // 탭바가 빠진 자리라 시트가 화면 바닥까지 내려간다 — 콘텐츠도 홈 인디케이터
                // 영역까지 채우게 해 바닥에 빈 띠가 남지 않게 한다.
                extendsContentBelowSafeArea: true
            ) {
                if let placeStore = coordinator.placeDetailStore {
                    PlaceDetailView(store: placeStore, detent: placeDetailDetent)
                }
            }
            // **표시마다 새 identity 를 준다.** 없으면 SwiftUI 가 같은 자리의 시트를 같은 뷰로 보고
            // 내부 @State 와 레이아웃을 재사용해, **두 번째 표시부터** 콘텐츠가 "이미 배치된 것"으로
            // 취급돼 등장 전환에 참여하지 않는다 — 컨테이너만 올라오고 콘텐츠는 제자리에 고정된
            // 채 드러나는 어긋난 연출이 된다(첫 표시만 정상이던 증상).
            // 핀 id 가 아니라 열람 횟수를 쓰는 이유는 ``HomeCoordinator/placeDetailEpoch`` 참조.
            .id(coordinator.placeDetailEpoch)
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
