import DesignSystem
import Domain
import PlaceDetailUI
import PlaceMapUI
import ProfileSetupUI
import RoomCreationUI
import RoomShareUI
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
            PlaceMapLayer(
                bottomInset: mapBottomInset,
                pins: detailStore?.state.pins ?? [],
                myLocation: coordinator.mapFocus?.coordinate,
                roomColor: coordinator.selectedRoom?.color,
                selectedPinID: coordinator.selectedPin?.id.value,
                onSelectPin: { detailStore?.send(.tapLocation($0)) }
            )
            // 루트·지도버튼·방리스트시트에 이미 `.sheet` 가 하나씩 붙어 있다(같은 뷰에 둘 달면 하나만
            // 뜬다). 지도 레이어는 `if` 밖이라 시트가 떠 있는 동안 사라지지 않는 유일한 빈 자리다 —
            // `filterBar` 는 `placeStore == nil`, `toast` 는 `toastMessage != nil` 일 때만 존재한다.
            .sheet(item: $coordinator.invitingRoom, content: inviteSheet)

            if let roomListStore {
                mapButtons(roomList: roomListStore)
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
        // **가드는 "생성"에만 걸고 "로드"에는 걸지 않는다.** 이 `.task` 는 껍데기가 다시 보일 때마다
        // 도는데(공동방 만들기에서 pop · 탭 복귀), `guard roomListStore == nil else { return }` 로
        // 통째로 막으면 방 목록이 **처음 한 번만** 조회된다 — 방을 만들고 돌아와도 목록에 없고,
        // 탭을 나갔다 와야(뷰가 새로 만들어져 store 가 nil 이 됨) 그제야 보인다.
        .task {
            let store: RoomListStore
            if let roomListStore {
                store = roomListStore
            } else {
                store = coordinator.makeRoomListStore()   // store 는 1회만 (@State 로 유지)
                roomListStore = store
            }
            store.send(.load)                             // 조회는 다시 보일 때마다
        }
        // 껍데기가 **사라지지 않는** 사이에 방이 늘어난 경우(공유 시트 위 커버에서 방 생성).
        // 위 `.task` 는 시트가 떠도 돌지 않으므로 그 경로는 이 신호로만 갱신된다.
        // 방을 만든 직후라 공동방이 반드시 있어 이 재조회가 유도 시트를 띄우지는 않는다.
        .onChange(of: coordinator.roomsRevision) { _, _ in roomListStore?.send(.load) }
        // FR-007 — 방을 만들고 돌아왔다. 위 `.task` 가 낸 재조회가 끝나는 대로 그 방 상세로 이어진다.
        .onChange(of: coordinator.createdRoomID) { _, id in
            guard id != nil, let roomID = coordinator.consumeCreatedRoomID() else { return }
            roomListStore?.send(.openCreatedRoom(roomID))
        }
        .task(id: coordinator.selectedRoom?.id) { syncDetailStore() }
        .task(id: coordinator.selectedPin?.id.value) { syncPlaceStore() }
        .sheet(item: $coordinator.sharingLocation, onDismiss: showShareToast) { location in
            RoomShareSheet(
                location: RoomSharePlace(
                    name: location.name, address: location.address, thumbnail: location.thumbnail
                ),
                makeStore: { coordinator.makeRoomShareStore(location: location) },
                createRoomItem: $coordinator.shareCreateRoomChild,
                onClose: { coordinator.sharingLocation = nil },
                onRoomCreated: coordinator.roomsDidChange
            ) { child, onFinished in
                // 저장 탭 헤더 "+" 와 같은 화면 — 건너뛰기 없음(showsSkip: false).
                // flow 소유는 이 Feature 몫이라 화면·finish 배선을 여기서 준다(시트는 결과만 받는다).
                RoomFormView(makeStore: child.makeRoomFormStore, showsSkip: false)
                    .flowRoot(child, onFinish: onFinished)
            }
            // `.presentationDetents` 는 시트가 직접 단다 — full 높이가 방 개수로 갈리는데
            // 그 개수는 시트 안의 `RoomShareStore` 만 안다(``RoomShareSheet`` 주석).
            .presentationCornerRadius(20)
            .presentationDragIndicator(.hidden)
            .presentationBackground(.mhBackgroundElevatedNormal)
        }
    }

    /// 지도 위 부유 버튼 줄 — '저장된 방'(005-1 ⑮) + 현위치(003-1 ⑦ · 005-1).
    ///
    /// **두 버튼의 노출 조건이 다르다.**
    /// - '저장된 방' 은 장소 상세를 보는 동안에만 뜬다. 그 장소가 다른 방에도 저장돼 있을 때만
    ///   눌린다("중복 저장된 장소 클릭 시에만 활성화된다").
    /// - 현위치는 **방 리스트에서도** 뜬다 — 003-1 ⑦ 이 이 버튼을 방 리스트의 항목으로 못박고
    ///   있고, 시안 `003-1-1 peek`·`003-1-2 half` 에도 그려져 있다. 방 상세(004-1-2 half
    ///   `1604:97399`·peek `1604:97350`)에만 없어 그때는 숨긴다. 늘 눌린다 — 권한·측위 결과로
    ///   갈리는 것은 누른 **뒤**의 일이라 미리 잠글 근거가 없다.
    ///
    /// 시트보다 **먼저** 그려 시트가 올라오면 그 뒤로 가려지게 둔다 — full 단계에서 따로 숨기지
    /// 않아도 된다. 시트를 손으로 끌어 올리는 동안 버튼이 따라 움직이지 않는 건 필터바와 같은 한계다.
    ///
    /// 자리 값의 근거는 ``PlaceMapButtonMetrics``.
    @ViewBuilder
    private func mapButtons(roomList: RoomListStore) -> some View {
        // 방 상세(장소 상세를 열지 않은 상태)에는 시안에 버튼이 없다 — 줄 자체를 그리지 않는다.
        if placeStore != nil || detailStore == nil {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: PlaceMapButtonMetrics.spacing) {
                    Spacer(minLength: 0)
                    if let placeStore {
                        SavedRoomsButton { placeStore.send(.tapSavedRooms) }
                            .disabled(!placeStore.state.canOpenSavedRooms)
                    }
                    MyLocationButton {
                        if let placeStore { placeStore.send(.tapMyLocation) } else { roomList.send(.tapMyLocation) }
                    }
                }
                .padding(.trailing, PlaceMapButtonMetrics.trailing)
                // 시트 윗끝에서 18 — 드러난 높이가 단계마다 다르므로 지금 단계의 것을 쓴다
                // (peek·half 둘 다 버튼이 보인다). 탭바가 시트를 덮는 만큼은 `mapBottomInset` 과
                // 같은 이유로 함께 되돌려 준다.
                .padding(.bottom, visiblePeek + tabBarCoverage + PlaceMapButtonMetrics.bottomGap)
            }
        }
    }

    /// 지금 단계에서 시트가 드러낸 높이(탭바 위로 보이는 pt). full 은 지도를 다 덮어 0 이다.
    private var visiblePeek: CGFloat {
        switch detent {
        case .low: peek.low ?? peek.medium
        case .medium: peek.medium
        case .full: 0
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

    /// 친구 초대 시트(004-4-2). 도메인 `Room` 을 그릴 값으로 옮기는 자리다 — 시트가 있는
    /// `RoomCreationUI` 는 `ProfileSetupUI`(아바타 그림)를 의존하지 않으므로 매핑을 여기서 한다.
    private func inviteSheet(_ room: Room) -> some View {
        RoomInviteSheetView(
            roomName: room.name,
            thumbnail: thumbnailKind(of: room),
            members: room.users.map {
                RoomInviteMember(
                    id: $0.userId,
                    name: $0.nickname,
                    // 목록 전체를 그리므로 `images(of:)` 를 쓰지 않는다 — 그건 헤더 pill 용이라
                    // `displayLimit`(5)에서 잘린다.
                    avatar: AvatarPalette.image(of: $0.avatarColor)
                )
            },
            makeStore: { coordinator.makeInviteFriendsStore(room: room) },
            onClose: { coordinator.invitingRoom = nil }
        )
        // `presentationDetents` 는 시트가 직접 단다(높이가 시안 값 하나로 고정).
        .presentationCornerRadius(20)
        .presentationDragIndicator(.hidden)   // 그래버는 시트가 직접 그린다
        .presentationBackground(.mhBackgroundElevatedNormal)
    }

    /// 방 리스트 카드(003-2 ③)와 같은 규칙 — 서버가 주는 색 이름을 팔레트 12색에 매핑하고, 모르는
    /// 이름이나 색 미선택이면 my-room 썸네일로 폴백한다.
    private func thumbnailKind(of room: Room) -> MHRoomThumbnailKind {
        switch room.type {
        case .personal:
            .myRoom
        case .shared:
            room.color.flatMap(RoomColorPalette.thumbnail(for:)).map { .color($0) } ?? .myRoom
        }
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
            // 방 상세로 복귀 — 005 ④ 가 "'나가기' 버튼 … 클릭 시 [004-1-2] 방 상세_half로
            // 이동한다" 로 도착 단계를 half 로 못박았다. 장소 상세를 full 로 보던 사람도
            // 방 상세는 half 로 받는다(진입을 half 로 강제하는 `syncDetailStore` 와 같은 규칙).
            guard placeStore != nil else { return }
            placeStore = nil
            withAnimation(.spring(duration: 0.3)) { detent = .medium }
        }
    }

    @ViewBuilder
    private func filterBar(roomList: RoomListStore) -> some View {
        VStack(spacing: 0) {
            if let detailStore {
                MHFilterBar(
                    sortOptions: Self.sortOptions,
                    selectedSort: sortIndexBinding(
                        get: { detailStore.state.sort },
                        set: { detailStore.send(.selectSort($0)) }
                    ),
                    categories: detailStore.state.categories,
                    selectedCategory: categoryBinding(detailStore),
                    sortMenuPresented: $sortMenuOpen
                )
            } else {
                // 003-1 ① — 드롭다운은 방 상세(004-1 ⑥)와 **같은 5가지**이고 기본은 "전체" 다.
                MHFilterBar(
                    sortOptions: Self.sortOptions,
                    selectedSort: sortIndexBinding(
                        get: { roomList.state.roomSort },
                        set: { roomList.send(.selectRoomSort($0)) }
                    ),
                    categories: Self.roomListCategories,
                    selectedCategory: roomCategoryBinding(roomList),
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
                    bottomInset: tabBarCoverage,
                    onCollapse: { withAnimation(.spring(duration: 0.3)) { detent = .medium } }
                )
            }
        }
        // 방 개수가 바뀌면 half 높이도 바뀐다(003-2 ①②). 목록이 오기 전 카드 1장 높이로 떴다가
        // 응답이 오는 순간 두세 장 높이로 **뛰므로**, 그 변화만 스프링으로 잇는다.
        // 값을 방 개수로 잡아 시트 단계 전환·드래그에는 걸리지 않게 한다(그쪽은 `MHBottomSheet` 몫).
        .animation(.spring(duration: 0.3), value: roomList.state.rooms.count)
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
        detent == .full ? 0 : visiblePeek + tabBarCoverage
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
    /// - 방 리스트 88 · 256/360/380 (003-1 ②③ · 003-2 ①②) — 시안이 "바텀네비게이션 높이 제외"
    ///   라고 못박아 기준이 같다. half 는 **드러낼 카드 수로 갈리므로** 방 개수를 넘겨 받는다.
    ///   숫자를 여기 적지 않고 ``RoomListContentView/Metric`` 에서 가져온다: 조각의 합이라
    ///   헤더·칩을 고치면 여기도 따라가야 한다.
    /// - 장소 상세 335 (005-1 ⑫) — 시안의 369 는 **화면 끝까지** 잰 값이다(375×812 프레임에서 실측
    ///   367pt). 그 화면은 탭바가 없어 하단 safe-area 가 홈 인디케이터 34pt 뿐이므로 369 − 34 다.
    /// - 방 상세 156·405 — 시안에 숫자가 없어 그대로 둔다. 확정되면 그때 맞춘다.
    private var peek: (low: CGFloat?, medium: CGFloat) {
        if placeStore != nil { return (nil, 335) }
        guard detailStore == nil else { return (156, 405) }
        let roomCount = roomListStore?.state.rooms.count ?? 0
        return (RoomListContentView.Metric.peek, RoomListContentView.Metric.half(roomCount: roomCount))
    }

    /// 003-1 ① · 004-1 ⑥ — 두 화면이 같은 5가지를 같은 순서로 그린다.
    private static let sortOptions = RoomDetailSort.allCases.map(\.rawValue)

    private static let roomListCategories = ["전체", "카페", "음식점"]

    private func roomCategoryBinding(_ store: RoomListStore) -> Binding<Int> {
        Binding(
            get: { store.state.categoryFilter },
            set: { store.send(.selectCategory($0)) }
        )
    }

    /// 인덱스 ↔ ``RoomDetailSort`` 변환. `MHFilterBar` 가 인덱스로만 말하기 때문에 필요하다.
    ///
    /// 방 리스트(003-1 ①)와 방 상세(004-1 ⑥)가 **같은 5가지를 같은 순서로** 그리므로 변환 규칙도
    /// 하나다 — 무엇을 읽고 어느 액션으로 보낼지만 화면마다 다르다.
    ///
    /// 범위 밖 인덱스는 무시한다. `MHFilterBar` 가 같은 배열을 그려 정상 경로에서는 오지 않지만,
    /// 옆의 `categoryBinding` 이 같은 이유로 이미 막고 있어 규칙을 맞춘다.
    private func sortIndexBinding(
        get: @escaping () -> RoomDetailSort,
        set: @escaping (RoomDetailSort) -> Void
    ) -> Binding<Int> {
        Binding(
            get: { RoomDetailSort.allCases.firstIndex(of: get()) ?? 0 },
            set: { index in
                guard RoomDetailSort.allCases.indices.contains(index) else { return }
                set(RoomDetailSort.allCases[index])
            }
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
