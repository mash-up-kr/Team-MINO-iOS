import DesignSystem
import SwiftUI

/// 저장 탭 flow 의 껍데기. 지도·상단 필터바·바텀시트 프레임을 소유하고 시트 안 내용만 갈아끼운다.
///
/// `detent` 를 시트가 아니라 여기서 들기 때문에, 시트 내용이 바뀌어도 높이 단계가 그대로 이어진다
/// (Figma 004 스펙 2-3 — "방 상세 half → 방 리스트 Half / 방 상세 Full → 방 리스트 Full").
///
/// 상단 필터바도 한 인스턴스만 두고 바인딩만 단계별로 갈아끼운다. full 에서는 시트가 화면을 다 덮어
/// 필터바가 가려지고, 같은 정렬·카테고리 값을 시트 안 툴바가 이어받는다(Figma `004-1-3`).
struct ArchiveShellView: View {
    private let coordinator: ArchiveCoordinator

    @State private var detent: MHBottomSheetDetent = .medium
    @State private var roomListStore: RoomListStore?
    @State private var detailStore: RoomDetailStore?

    /// 시트 dismiss 가 끝난 뒤 띄울 토스트. 닫힘과 같은 프레임에 띄우면
    /// 내려가는 시트가 토스트 자리를 덮어 초반이 가려진 채 시작한다.
    @State private var pendingToast: String?
    @State private var toastMessage: String?
    /// 토스트 발사 횟수. 자동 소멸 타이머의 수명을 문구가 아니라 이 값에 묶는다 —
    /// 같은 문구로 두 번 뜨면 문구를 id 로 쓴 타이머는 재시작하지 않는다.
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
        // store 생성과 최초 로드를 시트가 아니라 껍데기에서 1회만 한다 — 시트 내용은 단계 전환으로
        // 재생성될 수 있어, 콘텐츠 쪽에 두면 되돌아올 때마다 방 목록을 다시 부른다.
        .task {
            guard roomListStore == nil else { return }
            let store = coordinator.makeRoomListStore()
            roomListStore = store
            store.send(.load)
        }
        .task(id: coordinator.selectedRoom?.id) { syncDetailStore() }
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
            .presentationDragIndicator(.hidden)   // 그래버는 시안대로 시트 안에서 직접 그린다
            .presentationBackground(.mhBackgroundElevatedNormal)
        }
    }

    // MARK: - 공유 시트 · 토스트

    private var shareRooms: [RoomShareRoom] {
        roomListStore?.state.rooms.map(RoomShareRoom.init(from:)) ?? []
    }

    private func showPendingToast() {
        guard let pendingToast else { return }
        toastMessage = pendingToast
        toastToken += 1
        self.pendingToast = nil
    }

    // 시안 `1672:73661` — 하단에서 102(= 홈 인디케이터 34 + 68), 좌우 20.
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
                // 취소를 삼키면 안 된다. try? 로 받으면 새 토스트가 이 task 를 취소했을 때
                // sleep 이 즉시 반환하고, 이어지는 nil 대입이 **방금 뜬 토스트**를 지운다.
                let token = toastToken
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                // catch 는 sleep 재개 전 취소만 잡는다. 재개 후 같은 틱에 새 토스트가 뜨는
                // 좁은 창은 토큰 비교로 막는다 — 낡은 타이머는 최신 토스트를 지우면 안 된다.
                guard token == toastToken else { return }
                self.toastMessage = nil
            }
        }
    }

    // MARK: - 단계 전환

    /// 방 상세 단계로 올라오면 Store 를 만들고, 내려가면 버린다.
    private func syncDetailStore() {
        guard let room = coordinator.selectedRoom else {
            detailStore = nil
            return
        }
        let store = coordinator.makeRoomDetailStore(room: room)
        detailStore = store
        store.send(.load)
        // 스펙 3 — "방 상세 진입 시 바텀시트 높이 첫 기준은 004-1-2_방 상세 half".
        // 되돌아갈 때는 반대로 손대지 않는다(승계).
        withAnimation(.spring(duration: 0.3)) { detent = .medium }
    }

    // MARK: - 상단 필터바

    @ViewBuilder
    private func filterBar(roomList: RoomListStore) -> some View {
        VStack(spacing: 0) {
            if let detailStore {
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

    // MARK: - 시트

    private func sheet(roomList: RoomListStore) -> some View {
        MHBottomSheet(detent: $detent, lowPeek: peek.low, mediumPeek: peek.medium) {
            if let detailStore {
                RoomDetailView(store: detailStore, detent: detent)
            } else {
                RoomListView(
                    store: roomList,
                    isFull: detent == .full,
                    onCollapse: { withAnimation(.spring(duration: 0.3)) { detent = .medium } }
                )
            }
        }
        .accessibilityIdentifier(detailStore == nil ? "RoomList.sheet" : "RoomDetail.sheet")
    }

    /// 단계별 peek·half 높이(콘텐츠 pt — `MHBottomSheet` 가 하단 safe-area 를 더한다).
    ///
    /// - 방 리스트: peek 은 그래버(30)+헤더(60), half 는 카드 영역까지. 스펙 이상치는 244 지만
    ///   실제 그래버 간격 영역이 더 커(~54) 카드가 탭바에 잘려 실측 보정값 268 을 쓴다.
    /// - 방 상세: 시안 비율(peek 208/812 = 25.6%, half 439/812 = 54.1%)에 시뮬레이터 실측으로 맞춘 값.
    ///   `MHBottomSheet` 이 safe-area 안쪽 높이로 비율을 환산해 지정값보다 68pt 크게 나오므로 그만큼 뺐다.
    ///   peek 은 그래버 + 액션 row + `Header_Room` 까지 보인다.
    private var peek: (low: CGFloat, medium: CGFloat) {
        detailStore == nil ? (112, 268) : (156, 405)
    }

    // MARK: - 바인딩

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

    /// `MHFilterBar` 는 인덱스로만 말한다 — 화면 쪽에서 enum 과 맞바꾼다.
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
