import DesignSystem
import RoomCreationUI
import SwiftUI

struct ArchiveShellView: View {
    private let coordinator: ArchiveCoordinator

    @State private var detent: MHBottomSheetDetent = .medium
    @State private var roomListStore: RoomListStore?
    @State private var detailStore: RoomDetailStore?
    @State private var placeStore: PlaceDetailStore?

    /// 정렬 드롭다운 열림 상태를 화면이 쥔다 — 시트 드래그·단계 전환처럼 `MHFilterBar` 가
    /// 알 수 없는 신호로 닫아야 하기 때문이다.
    @State private var sortMenuOpen = false

    @State private var toastMessage: String?
    @State private var toastToken = 0

    init(coordinator: ArchiveCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        @Bindable var coordinator = coordinator
        ZStack {
            ArchiveMapLayer(
                bottomInset: mapBottomInset,
                pins: detailStore?.state.pins ?? [],
                roomColor: coordinator.selectedRoom?.color,
                selectedPinID: coordinator.selectedPin?.id.value,
                onSelectPin: { detailStore?.send(.tapLocation($0)) }
            )

            if let placeStore {
                savedRoomsButton(place: placeStore)
                    // 루트에는 이미 공유 시트가 붙어 있어(같은 뷰에 `.sheet` 를 둘 달면 하나만 뜬다)
                    // 저장된 방 시트는 버튼 쪽에 붙인다.
                    .sheet(item: $coordinator.savedRooms, content: savedRoomsSheet)
            }

            if let roomListStore {
                if placeStore == nil {
                    // zIndex 로 시트 위에 올리지 않는다. 올리면 바깥탭 스크림이 시트를 덮는데,
                    // 드래그는 onTapGesture 를 발동시키지 않아 시트가 움직이지도 메뉴가 닫히지도
                    // 않는다(시뮬레이터 확인). 메뉴는 최대 400pt 라 하단이 y≈530 이고 시트 top 은
                    // medium 에서 572, peek 에서 728 이라 이 순서로도 가려지지 않는다.
                    filterBar(roomList: roomListStore)
                }
                sheet(roomList: roomListStore)
                    // 루트에는 이미 공유 시트가 붙어 있다. 같은 뷰에 `.sheet` 를 둘 달면 하나만
                    // 뜨므로 방 리스트 시트 쪽에 붙인다.
                    .sheet(isPresented: createPromptBinding) {
                        RoomCreationPromptView(
                            onCreate: { roomListStore.send(.tapCreateRoom) },
                            onLater: { roomListStore.send(.tapLater) }
                        )
                        .presentationDetents([.height(RoomCreationPromptView.detentHeight)])
                        .presentationDragIndicator(.hidden)   // 그래버는 시트가 직접 그린다
                    }
            }

            toast
        }
        // 방 상세 헤더 케밥 드롭다운. peek 에서 시트 위(지도 위)로 떠야 해 시트 클립 밖인 여기서 그린다.
        .roomDetailMoreMenu(store: detailStore, detent: detent)
        .animation(.easeInOut(duration: 0.2), value: toastMessage)
        .onChange(of: detent) { _, _ in sortMenuOpen = false }
        .task {
            guard roomListStore == nil else { return }
            let store = coordinator.makeRoomListStore()
            roomListStore = store
            store.send(.load)
        }
        .task(id: coordinator.selectedRoom?.id) { syncDetailStore() }
        .task(id: coordinator.selectedPin?.id.value) { syncPlaceStore() }
        .sheet(item: $coordinator.sharingLocation, onDismiss: showShareToast) { location in
            RoomShareSheet(
                location: location,
                makeStore: { coordinator.makeRoomShareStore(location: location) },
                createRoomChild: $coordinator.shareCreateRoomChild,
                onClose: { coordinator.sharingLocation = nil }
            )
            .presentationDetents([.height(RoomShareSheet.detentHeight)])
            .presentationCornerRadius(20)
            .presentationDragIndicator(.hidden)
            .presentationBackground(.mhBackgroundElevatedNormal)
        }
    }

    /// 005-1 ⑮ — 지도 위 '저장된 방'. 장소 상세를 보는 동안에만 뜨고, 그 장소가 다른 방에도
    /// 저장돼 있을 때만 눌린다("중복 저장된 장소 클릭 시에만 활성화된다").
    ///
    /// 시트보다 **먼저** 그려 시트가 올라오면 그 뒤로 가려지게 둔다 — full 단계에서 따로 숨기지
    /// 않아도 된다. 시트를 손으로 끌어 올리는 동안 버튼이 따라 움직이지 않는 건 필터바와 같은 한계다.
    private func savedRoomsButton(place: PlaceDetailStore) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                SavedRoomsButton { place.send(.tapSavedRooms) }
                    .disabled(!place.state.canOpenSavedRooms)
            }
            .padding(.trailing, 20)
            // 시안(005-1 half `4170:129600`)에서 버튼 아래끝 423, 시트 윗끝 441 → 18.
            // `peek.medium` 은 시트가 안전영역 위로 드러내는 높이라 기준이 같다.
            .padding(.bottom, peek.medium + 18)
        }
    }

    private func savedRoomsSheet(_ presentation: SavedRoomsPresentation) -> some View {
        SavedRoomsSheet(
            rooms: presentation.rooms.map(RoomListItem.init(from:)),
            onSelect: coordinator.selectSavedRoom
        )
        .presentationDetents([.height(SavedRoomsSheet.detentHeight)])
        .presentationCornerRadius(20)
        .presentationDragIndicator(.hidden)   // 그래버는 시트가 직접 그린다
        .presentationBackground(.mhBackgroundElevatedNormal)
    }

    /// 스와이프 dismiss 도 reducer 를 거치게 한다 — state 와 실제 표시가 갈라지면 시트가 다시 안 뜬다.
    private var createPromptBinding: Binding<Bool> {
        Binding(
            get: { roomListStore?.state.isCreatePromptPresented ?? false },
            set: { if !$0 { roomListStore?.send(.dismissCreatePrompt) } }
        )
    }

    /// 공유 완료 토스트. **저장이 실제로 성공한 경우에만** 뜬다 — X 로 닫거나 저장에 실패했으면
    /// Coordinator 의 신호가 서지 않아 아무것도 안 뜬다. 시트가 닫힌 뒤(`onDismiss`)에 띄우는 이유는
    /// 시트 위가 아니라 그 자리에 스낵바가 남아야 하기 때문(기획 011-2).
    private func showShareToast() {
        guard coordinator.consumeSavedShare() else { return }
        toastMessage = "공유가 완료되었습니다."
        toastToken += 1
    }

    @ViewBuilder private var toast: some View {
        if let toastMessage {
            VStack {
                Spacer()
                MHSnackbar(title: toastMessage, icon: .checkThick)
                    .padding(.horizontal, 20)
                    // 011-2 스펙(node 2400:270035): "표출 위치는 스크린 하단에서 40px을 띄워 표시한다".
                    // 말 그대로 **스크린 바닥** 기준이라 아래 `ignoresSafeArea` 로 컨테이너 인셋을
                    // 벗어나 잰다 — 안 벗어나면 홈 인디케이터 34 가 더해져 74 가 된다.
                    // 홈 인디케이터와 겹치지도 않는다: 스낵바 48(`MHSnackbar` 단일 라인)이라
                    // 아래끝 40 · 위끝 88 인데, 인디케이터 영역은 바닥에서 34 까지다.
                    .padding(.bottom, 40)
            }
            // 익스텐션의 같은 스낵바(`SaveLinkView.snackbar`)도 화면 바닥에서 40 이다.
            .ignoresSafeArea(.container, edges: .bottom)
            .allowsHitTesting(false)
            .transition(.opacity)
            .task(id: toastToken) {
                let token = toastToken
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
                guard token == toastToken else { return }
                self.toastMessage = nil
            }
        }
    }

    private func syncDetailStore() {
        guard let room = coordinator.selectedRoom else {
            detailStore = nil
            return
        }
        let store = coordinator.makeRoomDetailStore(room: room)
        detailStore = store
        store.send(.load)
        // 방 리스트용 메뉴가 방 상세 필터바에 그대로 남지 않게 — 두 분기가 같은 if/else 안이라
        // SwiftUI 가 같은 인스턴스로 볼 수 있다.
        sortMenuOpen = false
        // 방 상세 "진입"만 Half 로 강제한다 — 스펙이 진입 기본값을 Half 로 못박고 있다.
        // 그 밖의 전환(장소 상세 왕복, 방 리스트 복귀)은 단계를 유지한다.
        withAnimation(.spring(duration: 0.3)) { detent = .medium }
    }

    private func syncPlaceStore() {
        if let pin = coordinator.selectedPin {
            placeStore = coordinator.makePlaceDetailStore(pin: pin)
            // 장소 상세는 low 를 쓰지 않으므로(detents: [.medium, .full]) low 였다면 medium 으로 올린다.
            // 그 밖에는 사용자가 보던 단계를 그대로 둔다 — full 로 보던 사람은 full 로 이어 본다.
            if detent == .low {
                withAnimation(.spring(duration: 0.3)) { detent = .medium }
            }
        } else {
            // 방 상세로 복귀 — 단계를 건드리지 않는다.
            guard placeStore != nil else { return }
            placeStore = nil
        }
    }

    @ViewBuilder
    private func filterBar(roomList: RoomListStore) -> some View {
        VStack(spacing: 0) {
            if let detailStore {
                MHFilterBar(
                    sortOptions: RoomDetailSort.allCases.map(\.rawValue),
                    selectedSort: sortBinding(detailStore),
                    categories: detailStore.state.categories,
                    selectedCategory: categoryBinding(detailStore),
                    sortMenuPresented: $sortMenuOpen
                )
            } else {
                MHFilterBar(
                    sortOptions: roomOptions(roomList),
                    selectedSort: binding(roomList, \.roomFilter, RoomListAction.selectRoomFilter),
                    categories: Self.roomListCategories,
                    selectedCategory: binding(roomList, \.categoryFilter, RoomListAction.selectCategory),
                    sortMenuPresented: $sortMenuOpen
                )
            }
            Spacer(minLength: 0)
        }
    }

    private func sheet(roomList: RoomListStore) -> some View {
        MHBottomSheet(
            detent: $detent,
            lowPeek: peek.low,
            mediumPeek: peek.medium,
            bottomCoverage: tabBarCoverage,
            detents: placeStore == nil ? MHBottomSheetDetent.allCases : [.medium, .full]
        ) {
            if let placeStore {
                PlaceDetailView(store: placeStore, detent: detent)
            } else if let detailStore {
                RoomDetailView(store: detailStore, detent: detent)
            } else {
                RoomListView(
                    store: roomList,
                    isFull: detent == .full,
                    onCollapse: { withAnimation(.spring(duration: 0.3)) { detent = .medium } }
                )
            }
        }
        .accessibilityIdentifier(sheetIdentifier)
    }

    private var sheetIdentifier: String {
        if placeStore != nil { return "PlaceDetail.sheet" }
        return detailStore == nil ? "RoomList.sheet" : "RoomDetail.sheet"
    }

    /// 시트가 지도를 가리는 높이. 구글 로고가 시트 위로 올라오도록 지도 padding 으로 넘긴다.
    /// `MapView` 가 safe-area 를 더해 적용하므로(`paddingAdjustmentBehavior = .always`)
    /// safe-area 를 뺀 값을 준다 — `MHBottomSheet` 에 주는 값과 기준이 같아, 탭바 보정도
    /// 함께 얹어야 로고가 시트 상단에 맞는다.
    /// full 은 지도가 전부 가려져 로고를 밀어올릴 여백이 없으므로 0.
    private var mapBottomInset: CGFloat {
        switch detent {
        case .low: (peek.low ?? peek.medium) + tabBarCoverage
        case .medium: peek.medium + tabBarCoverage
        case .full: 0
        }
    }

    /// 시트를 아래에서 덮는 탭바의 높이.
    ///
    /// 탭바는 `MainTabView` 가 `safeAreaInset` 으로 붙이는데 `NavigationStack` 이 그 인셋을
    /// 스택 안 콘텐츠에 전파하지 않는다(``MHTabBar/height``) — 시트는 탭바가 없는 것처럼
    /// safe area 바닥까지 자리를 잡아, 아래 52pt 가 탭바에 가린다. 그만큼을 되돌려 준다
    /// (`NotificationTabView`·`ProfileTabView` 의 `tabBarSpacer` 와 같은 보정).
    ///
    /// 탭바가 레이아웃에서 아예 빠지는 전체화면 상태(방 상세·장소 상세)에서는 덮는 게 없어 0 이다 —
    /// `MainTabView` 가 탭바를 넣고 빼는 조건과 **같은 값**을 보므로 이중 보정이 생기지 않는다.
    private var tabBarCoverage: CGFloat {
        coordinator.isFullBleedContentPresented ? 0 : MHTabBar.height
    }

    /// 시트 단계별 노출 높이 — 탭바를 뺀, 눈에 보이는 pt.
    ///
    /// `MHBottomSheet` 은 여기 준 값에 `bottomCoverage`(탭바) 만 더해 그린다. 홈 인디케이터는
    /// 시트의 레이아웃 상자 밖이라 더하지 않는다(`MHBottomSheet` 의 `fraction` 주석).
    ///
    /// - 방 리스트 88·256 (004-1 ②③) — 시안이 "바텀네비게이션 높이 제외" 라고 못박아 기준이 같다.
    /// - 장소 상세 335 (005-1 ⑫) — 시안의 369 는 **화면 끝까지** 잰 값이다(375×812 프레임에서 실측
    ///   367pt). 그 화면은 탭바가 없어 하단 safe-area 가 홈 인디케이터 34pt 뿐이므로 369 − 34 다.
    /// - 방 상세 156·405 — 시안에 숫자가 없어 그대로 둔다. 확정되면 그때 맞춘다.
    private var peek: (low: CGFloat?, medium: CGFloat) {
        if placeStore != nil { return (nil, 335) }
        return detailStore == nil ? (88, 256) : (156, 405)
    }

    private static let roomListCategories = ["전체", "카페", "음식점"]

    private func roomOptions(_ store: RoomListStore) -> [String] {
        ["전체"] + store.state.rooms.map(\.name)
    }

    private func binding(
        _ store: RoomListStore,
        _ keyPath: KeyPath<RoomListState, Int>,
        _ action: @escaping (Int) -> RoomListAction
    ) -> Binding<Int> {
        Binding(
            get: { store.state[keyPath: keyPath] },
            set: { store.send(action($0)) }
        )
    }

    private func sortBinding(_ store: RoomDetailStore) -> Binding<Int> {
        Binding(
            get: { RoomDetailSort.allCases.firstIndex(of: store.state.sort) ?? 0 },
            set: { store.send(.selectSort(RoomDetailSort.allCases[$0])) }
        )
    }

    private func categoryBinding(_ store: RoomDetailStore) -> Binding<Int> {
        Binding(
            get: { store.state.categories.firstIndex(of: store.state.category) ?? 0 },
            // 목록이 재조회로 줄어드는 사이 옛 인덱스가 들어올 수 있다 — 범위를 벗어나면 무시한다.
            set: { index in
                guard store.state.categories.indices.contains(index) else { return }
                store.send(.selectCategory(store.state.categories[index]))
            }
        )
    }
}
