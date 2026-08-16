import DesignSystem
import SwiftUI

/// 저장 탭 flow 의 껍데기. 지도·상단 필터바·바텀시트 프레임을 소유하고 시트 안 내용만 갈아끼운다.
///
/// `detent` 를 시트가 아니라 여기서 들기 때문에, 시트 내용이 바뀌어도 높이 단계가 그대로 이어진다
/// (Figma 004 스펙 2-3 — "방 상세 half → 방 리스트 Half / 방 상세 Full → 방 리스트 Full").
struct ArchiveShellView: View {
    private let coordinator: ArchiveCoordinator

    @State private var detent: MHBottomSheetDetent = .medium
    @State private var roomListStore: RoomListStore?

    init(coordinator: ArchiveCoordinator) {
        self.coordinator = coordinator
    }

    /// 디자인 정책(003-2): half 는 공동방 수와 무관하게 헤더+칩+개인방 카드 합산 높이(고정)를 유지한다
    /// (바텀 네비 제외). 스펙 이상치는 그래버(30)+헤더(60)+칩(50)+카드(104)=244 이지만,
    /// 실제 그래버 간격 영역이 더 커(~54) 카드가 탭바에 잘려 실측 보정값 268 을 쓴다(lowPeek 112 와 동일 논리).
    private let roomListMediumPeek: CGFloat = 268

    var body: some View {
        ZStack {
            ArchiveMapLayer()

            if let roomListStore {
                filterBar(store: roomListStore)
                sheet(store: roomListStore)
            }
        }
        // store 생성과 최초 로드를 시트가 아니라 껍데기에서 1회만 한다 — 시트 내용은 단계 전환으로
        // 재생성될 수 있어, 콘텐츠 쪽에 두면 되돌아올 때마다 방 목록을 다시 부른다.
        .task {
            guard roomListStore == nil else { return }
            let store = coordinator.makeRoomListStore()
            roomListStore = store
            store.send(.load)
        }
    }

    private func filterBar(store: RoomListStore) -> some View {
        VStack(spacing: 0) {
            MHFilterBar(
                sortOptions: roomOptions(store: store),
                selectedSort: binding(store, \.roomFilter, RoomListAction.selectRoomFilter),
                categories: Self.categories,
                selectedCategory: binding(store, \.categoryFilter, RoomListAction.selectCategory)
            )
            Spacer(minLength: 0)
        }
    }

    // low(peek) 는 그래버(30) + 헤더(60) 만, medium 은 카드 영역까지 — 둘 다 콘텐츠 pt 기반(MHBottomSheet 가 하단 safe-area 보정).
    private func sheet(store: RoomListStore) -> some View {
        MHBottomSheet(detent: $detent, lowPeek: 112, mediumPeek: roomListMediumPeek) {
            RoomListView(
                store: store,
                isFull: detent == .full,
                onCollapse: { withAnimation(.spring(duration: 0.3)) { detent = .medium } }
            )
        }
        .accessibilityIdentifier("RoomList.sheet")
    }

    private static let categories = ["전체", "카페", "음식점"]

    private func roomOptions(store: RoomListStore) -> [String] {
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
}
