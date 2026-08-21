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
                        // 방 단위 메뉴(시안 004-5 계열)가 정해지면 여기서 메뉴를 띄우고,
                        // 그 안의 "방 편집" 항목이 `onOutput(.editRoom(room))` 를 낸다.
                        // 받는 쪽(ProfileTabView·ProfileCoordinator)은 이미 준비돼 있다.
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
        // LazyVStack 은 자식의 zIndex 를 무시해 아래 카드가 열린 메뉴 위로 그려진다(시뮬레이터 확인).
        // 목 데이터 8건 수준이라 VStack 으로 두고, 서버 연동으로 목록이 길어지면 다시 본다.
        VStack(spacing: 0) {
            ForEach(Array(locations.enumerated()), id: \.element.id) { index, location in
                card(location, at: index)
                    .zIndex(menuLocationID == location.id ? 1 : 0)
            }
        }
        .padding(.horizontal, 20)
        .accessibilityIdentifier("RoomDetail.locationList")
    }

    /// 케밥 메뉴 배치·여닫음은 `MHLocationCard` 가 갖고 있다. 시트는 "어느 카드가 열려 있나"만 쥔다 —
    /// 카드마다 내부 상태를 쓰면 여러 개가 동시에 열린다(컴포넌트 문서 권고).
    @ViewBuilder private func card(_ location: RoomDetailLocation, at index: Int) -> some View {
        let presented = Binding(
            get: { menuLocationID == location.id },
            set: { overlay = $0 ? .locationMenu(location.id) : nil }
        )
        let items = RoomDetailMenuCatalog.locationItems { select($0, for: location) }
        // 목록 끝쪽 행은 아래로 펼치면 시트 클립에 잘린다 → 위로 연다.
        let placement: MHLocationCardMenuPlacement = index >= locations.count - 2 ? .above : .below

        switch viewMode {
        case .list:
            LocationCompactCard(location: location, menuItems: items, menuPlacement: placement, menuPresented: presented)
        case .grid:
            LocationExpandedCard(location: location, menuItems: items, menuPlacement: placement, menuPresented: presented)
        }
    }

    private func select(_ item: RoomDetailMenuItemID, for location: RoomDetailLocation) {
        overlay = nil
        switch item {
        case .shareLocation:
            onOutput(.shareLocation(location))
        // TODO: 시안이 확정되면 삭제·이동을 배선한다. 지금은 메뉴만 닫는다.
        case .deleteLocation, .moveLocation:
            break
        }
    }
}

#Preview("방 상세 시트") {
    ZStack {
        Color.mhFillAlternative.ignoresSafeArea()
        RoomDetailSheet(room: .sample, locations: RoomDetailLocation.samples) { _ in }
    }
}
