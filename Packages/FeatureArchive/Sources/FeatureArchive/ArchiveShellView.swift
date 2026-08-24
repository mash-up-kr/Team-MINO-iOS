import DesignSystem
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

    @State private var pendingToast: String?
    @State private var toastMessage: String?
    @State private var toastToken = 0

    init(coordinator: ArchiveCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        @Bindable var coordinator = coordinator
        ZStack {
            ArchiveMapLayer(bottomInset: mapBottomInset)

            if let roomListStore {
                if placeStore == nil {
                    filterBar(roomList: roomListStore)
                        // 열린 메뉴가 시트에 가리지 않도록 그 순간만 올린다. 상시 1 이면
                        // full 에서 시트가 필터바를 덮어야 하는 동작이 깨진다.
                        .zIndex(sortMenuOpen ? 1 : 0)
                }
                sheet(roomList: roomListStore)
            }

            toast
        }
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
        .sheet(item: $coordinator.sharingLocation, onDismiss: showPendingToast) { location in
            RoomShareSheet(
                location: location,
                rooms: shareRooms,
                onClose: { coordinator.sharingLocation = nil },
                onSubmit: { _ in
                    pendingToast = "공유가 완료됐습니다."
                    coordinator.sharingLocation = nil
                }
            )
            .presentationDetents([.height(RoomShareSheet.detentHeight)])
            .presentationCornerRadius(20)
            .presentationDragIndicator(.hidden)
            .presentationBackground(.mhBackgroundElevatedNormal)
        }
    }

    private var shareRooms: [RoomShareRoom] {
        roomListStore?.state.rooms.map(RoomShareRoom.init(from:)) ?? []
    }

    private func showPendingToast() {
        guard let pendingToast else { return }
        toastMessage = pendingToast
        toastToken += 1
        self.pendingToast = nil
    }

    @ViewBuilder private var toast: some View {
        if let toastMessage {
            VStack {
                Spacer()
                MHSnackbar(title: toastMessage, icon: .checkThick)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 68)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
            .task(id: toastToken) {
                let token = toastToken
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
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
        withAnimation(.spring(duration: 0.3)) { detent = .medium }
    }

    private func syncPlaceStore() {
        if let pin = coordinator.selectedPin {
            placeStore = coordinator.makePlaceDetailStore(pin: pin)
        } else {
            guard placeStore != nil else { return }
            placeStore = nil
        }
        withAnimation(.spring(duration: 0.3)) { detent = .medium }
    }

    @ViewBuilder
    private func filterBar(roomList: RoomListStore) -> some View {
        VStack(spacing: 0) {
            if let detailStore {
                MHFilterBar(
                    sortOptions: RoomDetailSort.allCases.map(\.rawValue),
                    selectedSort: sortBinding(detailStore),
                    categories: RoomDetailCategory.allCases.map(\.rawValue),
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
    /// `MHBottomSheet` 에 주는 peek 원본 pt 를 그대로 준다 — 두 값의 기준이 같다.
    /// full 은 지도가 전부 가려져 로고를 밀어올릴 여백이 없으므로 0.
    private var mapBottomInset: CGFloat {
        switch detent {
        case .low: peek.low ?? peek.medium
        case .medium: peek.medium
        case .full: 0
        }
    }

    private var peek: (low: CGFloat?, medium: CGFloat) {
        if placeStore != nil { return (nil, 329) }
        return detailStore == nil ? (112, 268) : (156, 405)
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
            get: { RoomDetailCategory.allCases.firstIndex(of: store.state.category) ?? 0 },
            set: { store.send(.selectCategory(RoomDetailCategory.allCases[$0])) }
        )
    }
}
