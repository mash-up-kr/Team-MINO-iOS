import DesignSystem
import Domain
import MVI
import SwiftUI

struct RoomDetailView: View {
    let store: RoomDetailStore
    let detent: MHBottomSheetDetent

    /// 동시에 하나만 떠야 하는 오버레이(정렬 드롭다운 / 장소 케밥 메뉴).
    /// Bool 두 개로 두면 정렬을 연 채 케밥을 탭했을 때 둘이 겹친다 — 단일 enum 으로 상호배제를 타입으로 강제한다.
    enum Overlay: Equatable {
        case sort
        /// 순번이 아니라 식별자로 잡아야 목록이 바뀌어도 엉뚱한 카드에 붙지 않는다.
        case locationMenu(RoomDetailLocation.ID)
    }

    @State private var overlay: Overlay?

    private var locations: [RoomDetailLocation] { store.state.locations }

    var body: some View {
        MHBottomSheetScrollView {
            VStack(spacing: 0) {
                RoomDetailHeader(
                    room: store.state.room,
                    onAddMember: { store.send(.tapAddMember) },
                    onMore: { store.send(.tapMore) },
                    onClose: { store.send(.tapClose) }
                )

                if detent == .full {
                    toolbar
                    categoryRow
                }

                locationList
            }
        }
        .task(id: ObjectIdentifier(store)) {
            // 방장 판정용 신원 조회. 장소 목록(`.load`)은 껍데기가 보내므로 여기선 이것만 챙긴다.
            store.send(.loadCurrentMember)
        }
        .onChange(of: detent) { _, _ in
            overlay = nil
            // 단계가 바뀌면 케밥 메뉴가 열리는 방향도 바뀐다 — 열린 채로 자리만 튀지 않게 닫는다.
            store.send(.dismissMoreMenu)
        }
        // 헤더 케밥은 시트 밖에서 그려져 이 뷰의 `overlay` 상호배제에 끼지 못한다 —
        // 서로 열릴 때 상대를 닫아 "정렬 드롭다운 위에 케밥 메뉴" 같은 겹침을 막는다.
        .onChange(of: overlay) { _, opened in
            if opened != nil { store.send(.dismissMoreMenu) }
        }
        .onChange(of: store.state.isMoreMenuPresented) { _, opened in
            if opened { overlay = nil }
        }
        .mhDialog(item: store.state.deletion) { deletion in
            MHDialog(
                title: "이 장소를 삭제할까요?",
                message: "장소에 등록된 사진과 댓글이 모두 삭제되며, 다시 되돌릴 수 없어요.",
                cancel: MHAction("취소", isEnabled: !deletion.isSubmitting) { store.send(.cancelDelete) },
                confirm: MHAction("삭제", isEnabled: !deletion.isSubmitting) { store.send(.confirmDelete) }
            )
        }
        // 004-5 방 나가기. 전용 시안이 없어 같은 앱의 확인 모달 공통 꼴을 따른다 —
        // "이 …할까요?" + 되돌릴 수 없다는 한 줄 + 취소/실행 두 버튼(장소 삭제와 같다).
        .mhDialog(item: store.state.leave) { leave in
            MHDialog(
                title: leave.deletesRoom ? "방을 나가면 삭제돼요" : "이 방에서 나갈까요?",
                message: Self.leaveMessage(leave),
                cancel: MHAction("취소", isEnabled: !leave.isSubmitting) { store.send(.cancelLeave) },
                confirm: MHAction("나가기", isEnabled: !leave.isSubmitting) { store.send(.confirmLeave) }
            )
        }
    }

    /// 나가기 다이얼로그 본문. 실패했으면 그 자리에서 사유로 바꿔 재시도하게 둔다 —
    /// 닫아 버리면 "눌렀는데 아무 일도 없다" 로 보인다.
    private static func leaveMessage(_ leave: RoomDetailLeave) -> String {
        if leave.failed { return "방에서 나가지 못했어요. 잠시 후 다시 시도해 주세요." }
        return leave.deletesRoom
            // 서버가 그렇게 동작한다 — 방장이 마지막 멤버면 나가기가 곧 방 삭제다.
            ? "혼자 있는 방이라 나가면 방과 저장한 장소가 모두 사라지고, 다시 되돌릴 수 없어요."
            : "이 방에 저장된 장소를 더 이상 볼 수 없어요. 다시 초대받으면 들어올 수 있어요."
    }

    private var toolbar: some View {
        RoomDetailToolbar(
            sort: store.state.sort,
            viewMode: store.state.viewMode,
            isSortExpanded: overlay == .sort,
            onToggleSort: { overlay = overlay == .sort ? nil : .sort },
            onSelectViewMode: {
                store.send(.selectViewMode($0))
                overlay = nil   // 리스트/카드 전환 시 열린 메뉴가 어긋난 위치에 남지 않게
            },
            sortMenu: {
                RoomDetailSortMenu(selected: store.state.sort) { picked in
                    store.send(.selectSort(picked))
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
                ForEach(PlaceCategoryFilter.allCases, id: \.self) { item in
                    let isActive = item == store.state.category
                    MHChip(
                        item.chipTitle,
                        variant: isActive ? .solid : .outlined,
                        size: .large,
                        isActive: isActive
                    ) {
                        store.send(.selectCategory(item))
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
        VStack(spacing: 0) {
            ForEach(Array(locations.enumerated()), id: \.element.id) { index, location in
                card(location, at: index)
                    .contentShape(Rectangle())
                    .onTapGesture { store.send(.tapLocation(location.id)) }
                    .accessibilityIdentifier("RoomDetail.locationCard.\(location.id)")
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

        switch store.state.viewMode {
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
            store.send(.tapShare(location))
        case .deleteLocation:
            store.send(.tapDeleteLocation(location.id))
        }
    }
}

#Preview("방 상세 시트") {
    let store = RoomDetailStore(
        RoomDetailState(room: .sample, locations: RoomDetailLocation.samples),
        reduce: { _, _ in .none }
    )
    return ZStack {
        Color.mhFillAlternative.ignoresSafeArea()
        RoomDetailView(store: store, detent: .full)
    }
}
