import DesignSystem
import SwiftUI

/// 방 상세 바텀시트. Figma `004-1-1 peek` / `004-1-2 half` / `004-1-3 full`.
/// `MHBottomSheet` 은 딤 없는 비모달이라 띄우는 화면의 ZStack 에 겹쳐 놓는다.
struct RoomDetailSheet: View {
    let room: RoomDetailRoom
    let locations: [RoomDetailLocation]
    let onClose: () -> Void

    @State private var detent: MHBottomSheetDetent = .low
    @State private var viewMode: RoomDetailViewMode = .list
    @State private var sort: RoomDetailSort = .pick
    @State private var category: RoomDetailCategory = .all
    @State private var isSortExpanded = false

    // peek = 그래버 30 + 액션 row 60 + Header_Room 118, half = peek + 카드 2장
    private let peekFraction: CGFloat = 208.0 / 812.0
    private let halfFraction: CGFloat = 444.0 / 812.0

    var body: some View {
        MHBottomSheet(detent: $detent, lowFraction: peekFraction, mediumFraction: halfFraction) {
            MHBottomSheetScrollView {
                VStack(spacing: 0) {
                    RoomDetailHeader(
                        room: room,
                        onAddMember: {},
                        onMore: {},
                        onClose: onClose
                    )

                    if detent == .full {
                        toolbar
                        categoryRow
                    }

                    locationList
                }
            }
        }
        .onChange(of: detent) { _, _ in
            isSortExpanded = false
        }
    }

    private var toolbar: some View {
        RoomDetailToolbar(
            sort: sort,
            viewMode: viewMode,
            isSortExpanded: isSortExpanded,
            onToggleSort: { isSortExpanded.toggle() },
            onSelectViewMode: { viewMode = $0 },
            sortMenu: {
                RoomDetailSortMenu(selected: sort) { picked in
                    sort = picked
                    isSortExpanded = false
                }
            }
        )
        .zIndex(1)
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(RoomDetailCategory.allCases) { item in
                    MHChip(
                        item.rawValue,
                        variant: item == category ? .solid : .outlined,
                        size: .large,
                        isActive: item == category
                    ) {
                        category = item
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 56)
        // 가로 스크롤이 시트 드래그를 먹지 않게 잠근다
        .scrollDisabled(true)
    }

    private var locationList: some View {
        LazyVStack(spacing: 0) {
            ForEach(locations) { location in
                switch viewMode {
                case .list: LocationRowCard(location: location, onMore: {})
                case .grid: LocationGridCard(location: location, onMore: {})
                }
            }
        }
        .padding(.horizontal, 20)
        .accessibilityIdentifier("RoomDetail.locationList")
    }
}

#Preview("방 상세 시트") {
    ZStack {
        Color.mhFillAlternative.ignoresSafeArea()
        RoomDetailSheet(room: .sample, locations: RoomDetailLocation.samples) {}
    }
}
