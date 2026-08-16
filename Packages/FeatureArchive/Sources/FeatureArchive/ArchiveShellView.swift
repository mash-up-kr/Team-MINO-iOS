import DesignSystem
import SwiftUI

struct ArchiveShellView: View {
    private let coordinator: ArchiveCoordinator

    @State private var detent: MHBottomSheetDetent = .medium
    @State private var roomListStore: RoomListStore?
    @State private var detailStore: RoomDetailStore?
    @State private var placeStore: PlaceDetailStore?

    @State private var pendingToast: String?
    @State private var toastMessage: String?
    @State private var toastToken = 0

    init(coordinator: ArchiveCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        @Bindable var coordinator = coordinator
        ZStack {
            ArchiveMapLayer()

            if let roomListStore {
                filterBar(roomList: roomListStore)
                sheet(roomList: roomListStore)
            }

            toast
        }
        .animation(.easeInOut(duration: 0.2), value: toastMessage)
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
        withAnimation(.spring(duration: 0.3)) { detent = .medium }
    }

    /// 장소 상세는 진입도 복귀도 half 로 맞춘다(스펙 ④) — 방 상세와 달리 높이를 승계하지 않는다.
    private func syncPlaceStore() {
        guard let pin = coordinator.selectedPin else {
            guard placeStore != nil else { return }
            placeStore = nil
            withAnimation(.spring(duration: 0.3)) { detent = .medium }
            return
        }
        placeStore = coordinator.makePlaceDetailStore(pin: pin)
        withAnimation(.spring(duration: 0.3)) { detent = .medium }
    }

    @ViewBuilder
    private func filterBar(roomList: RoomListStore) -> some View {
        VStack(spacing: 0) {
            if placeStore != nil {
                EmptyView()   // 장소 상세엔 정렬·카테고리가 없다
            } else if let detailStore {
                MHFilterBar(
                    sortOptions: RoomDetailSort.allCases.map(\.rawValue),
                    selectedSort: sortBinding(detailStore),
                    categories: RoomDetailCategory.allCases.map(\.rawValue),
                    selectedCategory: categoryBinding(detailStore)
                )
            } else {
                MHFilterBar(
                    sortOptions: roomOptions(roomList),
                    selectedSort: binding(roomList, \.roomFilter, RoomListAction.selectRoomFilter),
                    categories: Self.roomListCategories,
                    selectedCategory: binding(roomList, \.categoryFilter, RoomListAction.selectCategory)
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

    private var peek: (low: CGFloat, medium: CGFloat) {
        if placeStore != nil { return (156, 329) }
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
