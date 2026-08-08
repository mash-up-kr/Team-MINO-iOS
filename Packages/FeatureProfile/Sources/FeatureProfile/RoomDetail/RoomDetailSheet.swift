import DesignSystem
import SwiftUI

/// 방 상세 바텀시트. Figma `004-1-1 peek` / `004-1-2 half` / `004-1-3 full`.
/// `MHBottomSheet` 은 딤 없는 비모달이라 띄우는 화면의 ZStack 에 겹쳐 놓는다.
struct RoomDetailSheet: View {
    let room: RoomDetailRoom
    let locations: [RoomDetailLocation]
    let onOutput: (RoomDetailOutput) -> Void

    /// 동시에 하나만 떠야 하는 오버레이(정렬 드롭다운 / 장소 케밥 메뉴).
    /// Bool 두 개로 두면 정렬을 연 채 케밥을 탭했을 때 둘이 겹친다 — 단일 enum 으로 상호배제를 타입으로 강제한다.
    enum Overlay: Equatable {
        case sort
        /// 순번이 아니라 식별자로 잡아야 목록이 바뀌어도 엉뚱한 카드에 붙지 않는다.
        case locationMenu(RoomDetailLocation.ID)
    }

    @State private var detent: MHBottomSheetDetent = .low
    @State private var viewMode: RoomDetailViewMode = .list
    @State private var sort: RoomDetailSort = .pick
    @State private var category: RoomDetailCategory = .all
    @State private var overlay: Overlay?

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
                        onClose: { onOutput(.close) }
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
            overlay = nil
        }
    }

    private var toolbar: some View {
        RoomDetailToolbar(
            sort: sort,
            viewMode: viewMode,
            isSortExpanded: overlay == .sort,
            onToggleSort: { overlay = overlay == .sort ? nil : .sort },
            onSelectViewMode: {
                viewMode = $0
                overlay = nil   // 리스트/카드 전환 시 열린 메뉴가 어긋난 위치에 남지 않게
            },
            sortMenu: {
                RoomDetailSortMenu(selected: sort) { picked in
                    sort = picked
                    overlay = nil
                }
            }
        )
        .zIndex(1)
    }

    private var menuLocationID: RoomDetailLocation.ID? {
        if case .locationMenu(let id) = overlay { return id }
        return nil
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
                card(location)
                    .anchorPreference(key: RoomDetailMenuAnchorKey.self, value: .bounds) {
                        menuLocationID == location.id ? $0 : nil
                    }
            }
        }
        .padding(.horizontal, 20)
        // 메뉴를 행의 overlay 로 두면 LazyVStack 형제의 zIndex 가 먹지 않아 아래 카드가 메뉴 위로 그려진다.
        // 그래서 목록 전체의 overlay 로 올리고, 열린 행의 앵커로 위치만 잡는다.
        .overlayPreferenceValue(RoomDetailMenuAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor, let location = locations.first(where: { $0.id == menuLocationID }) {
                    let card = proxy[anchor]
                    locationMenu(location)
                        .offset(x: card.maxX - Self.menuWidth, y: card.minY + kebabBottom)
                }
            }
        }
        .accessibilityIdentifier("RoomDetail.locationList")
    }

    @ViewBuilder private func card(_ location: RoomDetailLocation) -> some View {
        // 같은 케밥을 다시 누르면 닫힌다(정렬 드롭다운과 동일한 토글 동작)
        let onMore = {
            overlay = menuLocationID == location.id ? nil : .locationMenu(location.id)
        }
        switch viewMode {
        case .list: LocationRowCard(location: location, onMore: onMore)
        case .grid: LocationGridCard(location: location, onMore: onMore)
        }
    }

    /// Figma `Menu/Menu` 폭(`1672:75163`).
    private static let menuWidth: CGFloat = 140

    /// 카드 상단에서 케밥 아이콘 아래끝까지 — 카드 세로 여백 12 + 아이콘 높이(리스트 18 / 그리드 24).
    private var kebabBottom: CGFloat { viewMode == .list ? 30 : 36 }

    // 케밥 바로 아래에 우측 끝을 맞춰 펼친다.
    private func locationMenu(_ location: RoomDetailLocation) -> some View {
        MHMenu(RoomDetailMenuCatalog.locationItems { select($0, at: location.id) })
            .frame(width: Self.menuWidth)
            .accessibilityIdentifier("RoomDetail.locationMenu")
    }

    private func select(_ item: RoomDetailMenuItemID, at locationID: RoomDetailLocation.ID) {
        overlay = nil
        switch item {
        case .shareLocation:
            onOutput(.shareLocation(locationID))
        // TODO: 시안이 확정되면 삭제·이동을 배선한다. 지금은 메뉴만 닫는다.
        case .deleteLocation, .moveLocation:
            break
        }
    }
}

/// 케밥 메뉴가 열린 장소 카드의 위치. 목록 전체 overlay 가 이 앵커로 메뉴를 배치한다.
private struct RoomDetailMenuAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

#Preview("방 상세 시트") {
    ZStack {
        Color.mhFillAlternative.ignoresSafeArea()
        RoomDetailSheet(room: .sample, locations: RoomDetailLocation.samples) { _ in }
    }
}
