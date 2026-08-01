import DesignSystem
import SwiftUI

/// 방 상세 바텀시트. Figma `004-1-1 peek` / `004-1-2 half` / `004-1-3 full`.
///
/// `MHBottomSheet` 는 딤 없는 비모달이라 `.sheet` 가 아니라 **띄우는 화면의 ZStack 에 겹쳐** 놓는다.
/// 단계별로 보이는 것:
/// - `low`(peek): 헤더만 (시트 높이에 나머지가 잘림)
/// - `medium`(half): 헤더 + 장소 카드
/// - `full`: 정렬/보기 툴바와 카테고리 칩까지 노출되고 스크롤이 열린다
struct RoomDetailSheet: View {
    let room: RoomDetailRoom
    let locations: [RoomDetailLocation]
    let onClose: () -> Void

    @State private var detent: MHBottomSheetDetent = .low
    @State private var viewMode: RoomDetailViewMode = .list
    @State private var sort: RoomDetailSort = .pick
    @State private var category: RoomDetailCategory = .all
    @State private var isSortExpanded = false

    // peek = 그래버 30 + 액션 row 60 + Header_Room 118 = 208 / 812 (Figma 실측)
    // half = peek + 리스트 카드 2장(118×2) = 444 / 812
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
            isSortExpanded = false   // 시트 높이가 바뀌면 드롭다운은 닫는다(툴바가 사라질 수 있음)
        }
    }

    // MARK: - full 전용 영역

    private var toolbar: some View {
        RoomDetailToolbar(
            sort: sort,
            viewMode: viewMode,
            isSortExpanded: isSortExpanded,
            onToggleSort: { isSortExpanded.toggle() },
            onSelectViewMode: { viewMode = $0 }
        )
        .overlay(alignment: .bottomLeading) {
            if isSortExpanded {
                RoomDetailSortMenu(selected: sort) { picked in
                    sort = picked
                    isSortExpanded = false
                }
                .padding(.leading, 20)
                // bottomLeading 정렬이라 기본은 툴바 안쪽 위로 뜬다 — 자기 높이만큼 내려
                // 툴바 바로 아래에 붙인다(시안: 카테고리 칩·카드 위에 겹침)
                .offset(y: RoomDetailSortMenu.height)
            }
        }
        .zIndex(1)   // VStack 뒤 형제(카테고리·카드) 위로 드롭다운이 덮이도록
    }

    // Figma Category/Category(1672:65915) — h56, px20, gap10
    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(RoomDetailCategory.allCases) { item in
                    MHChip(
                        item.rawValue,
                        variant: item == category ? .solid : .outlined,
                        size: .medium,
                        isActive: item == category
                    ) {
                        category = item
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 56)
        .scrollDisabled(true)   // 칩 3개는 항상 화면에 들어와 가로 스크롤이 시트 드래그를 먹지 않게 한다
    }

    // MARK: - 목록

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

// MARK: - Preview

#Preview("방 상세 시트") {
    ZStack {
        Color.mhFillAlternative.ignoresSafeArea()
        RoomDetailSheet(room: .sample, locations: RoomDetailLocation.samples) {}
    }
}
