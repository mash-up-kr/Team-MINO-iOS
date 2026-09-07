import Core
import Domain
import MVI

/// 방 리스트 화면 상태 — 단일 `Equatable` struct.
/// 빈/로딩/에러 UI 는 이번 범위 밖(screen.md)이라 로딩 플래그를 두지 않는다.
public struct RoomListState: Equatable {
    public var rooms: [Room]
    /// 선택된 필터 칩 인덱스(전체/최근 저장 순/코멘트 순). 정렬 로직은 미구현(UI 상태만).
    public var filter: Int
    /// 지도 위 필터 드롭다운(003-1 ①). 방 상세(004-1 ⑥)와 **같은 5가지**이고 기본은 `.all` 이다.
    /// **서버가 이 기준으로 정렬해 준다** — 화면은 받은 순서대로 마커를 그린다.
    public var roomSort: PinSort
    /// 지도 위 카테고리 칩(003-1 ①). 3종 고정이며 서버가 이 값으로 거른다.
    public var category: PlaceCategoryFilter
    /// 지도에 그릴 **내 모든 방의 장소**(PRD [SYS-004] "내 모든 방의 장소 마커를 한 지도에").
    /// 방 목록과 달리 정렬·필터가 걸리므로 칩을 바꾸면 이 값만 다시 받는다.
    public var pins: [Pin] = []
    /// 공동방 생성 유도 시트(001-2-1)가 떠 있는가.
    public var isCreatePromptPresented: Bool
    /// 다음 **로드 응답 1회**는 유도 시트를 띄우지 않는다 — 만들기 화면에 다녀온 직후의 복귀.
    /// 성공·실패 어느 쪽으로 끝나든 소비된다. 실패에서 안 지우면 true 로 남아 다음 정상 진입의
    /// 시트가 조용히 안 뜬다.
    public var skipsNextCreatePrompt = false

    /// 거리순 정렬의 기준점인 내 위치. 한 번 받아 두고 이 화면이 사는 동안 다시 묻지 않는다
    /// (방 상세 `RoomDetailState.myCoordinate` 와 같은 규칙).
    public var myCoordinate: Coordinate?
    /// 거리순 **정렬 선택**이 좌표를 기다리는 중. 현위치 **버튼**의 `isLocating` 과 나눠 둔다 —
    /// 둘은 좌표를 얻은 뒤 하는 일이 다르다(정렬은 재조회, 버튼은 카메라 이동).
    public var isLocatingForSort = false

    /// 현위치 요청(003-1 ⑦)이 진행 중인가. 연타로 시스템 권한 팝업을 두 번 띄우지 않기 위한 가드.
    public var isLocating = false

    /// 목록이 도착하면 곧바로 열어야 할 방 — 방금 만든 방이다(spec FR-007 "생성 완료 시 방 상세로 직행").
    /// 만들기 화면은 방 id 만 돌려주는데 상세는 방 전체(멤버·장소 수)를 필요로 해서, 재조회를 기다렸다
    /// 그 응답에서 찾아 연다.
    public var pendingOpenRoomID: String?

    public init(
        rooms: [Room] = [],
        filter: Int = 0,
        roomSort: PinSort = .all,
        category: PlaceCategoryFilter = .all,
        isCreatePromptPresented: Bool = false
    ) {
        self.rooms = rooms
        self.filter = filter
        self.roomSort = roomSort
        self.category = category
        self.isCreatePromptPresented = isCreatePromptPresented
    }

    /// 지금 지도가 고른 조회 조건. 요청을 낼 때와 응답을 받아들일지 판단할 때 같은 값을 본다.
    var query: PinQuery { PinQuery(sort: roomSort, category: category) }

    /// 공동방을 하나라도 가졌는가. 빈 상태 노출과 유도 시트가 같은 기준을 봐야 해서 여기서 한 번만 정의한다.
    public var hasSharedRoom: Bool {
        rooms.contains { $0.type == .shared }
    }

    /// 목록에서 id 로 방을 찾는다 — 방금 만든 방을 상세로 잇는 두 경로(`.openCreatedRoom` 과
    /// 그 예약을 소비하는 `.loaded`)가 함께 쓴다.
    func room(id: String) -> Room? {
        rooms.first { $0.id == id }
    }

    /// 억제 플래그를 읽고 지운다. 반환값이 `true` 면 이번 응답은 시트 판정을 건너뛴다.
    mutating func consumeSkipFlag() -> Bool {
        defer { skipsNextCreatePrompt = false }
        return skipsNextCreatePrompt
    }
}

public enum RoomListAction: Equatable {
    case load
    /// Response Action (성공). 유도 시트 표출 판정에 필요한 스누즈 상태를 함께 싣는다 —
    /// reduce 는 순수해야 해서 `UserDefaults` 를 직접 읽을 수 없다.
    case loaded([Room], pins: [Pin], isPromptSnoozed: Bool)
    /// 칩을 바꿔 마커만 다시 받은 결과. 어떤 조건으로 낸 요청인지 함께 실어 늦게 온 응답을 버린다.
    case pinsLoaded([Pin], for: PinQuery)
    /// 거리순 정렬이 기다린 좌표. 현위치 버튼의 `.myLocationResolved` 와 하는 일이 다르다.
    case sortLocationResolved(CurrentLocationResult)
    /// 지도 마커 탭(핀 id).
    case tapPin(String)
    /// 저장 탭 최초 진입 — 지도가 실제로 그려지는 시점의 위치 권한 요청(003-1 ⑦).
    case requestLocationOnEntry
    /// 진입 시 요청의 결과. 버튼(`.myLocationResolved`)·정렬(`.sortLocationResolved`)과
    /// 하는 일이 또 다르다 — 카메라도 옮기지 않고 정렬도 세우지 않는다.
    case entryLocationResolved(CurrentLocationResult)
    case loadFailed(DomainError)   // Response Action (실패)
    case selectFilter(Int)
    case selectRoomSort(PinSort)
    case selectCategory(PlaceCategoryFilter)
    /// 지도 우하단 현위치 버튼(003-1 ⑦).
    case tapMyLocation
    /// Response Action — 권한·측위 결과.
    case myLocationResolved(CurrentLocationResult)
    case tapRoom(Room)
    /// 유도 시트·빈 상태 CTA·헤더 "+" 가 공유하는 진입 액션.
    case tapCreateRoom
    /// 방을 만들고 돌아왔다 — 그 방 상세로 이어 간다(spec FR-007).
    case openCreatedRoom(String)
    /// "나중에 만들래요" — 닫고 2주 동안 다시 띄우지 않는다.
    case tapLater
    /// 시트가 닫혔다(스와이프 등). 닫기만 하고 미루지는 않는다.
    case dismissCreatePrompt
}

public enum RoomListNav: Equatable, Sendable {
    case openRoomDetail(Room)
    /// 지도 마커를 눌렀다 — 그 장소 상세로. PRD [SYS-004]: "마커 클릭: … 하단 시트가 [SCR-006]
    /// 장소 상세 `Half` 로 전환된다", "중복 장소 마커 클릭 시에도 … 방을 먼저 고르게 하지 않고".
    case openPlaceDetail(Pin)
    /// 공동방 만들기 화면으로.
    case goToCreateRoom
    /// 지도 카메라를 내 위치로(003-1 ⑦). 화면 전환이 아니라 지도에 내리는 명령이지만,
    /// 받는 쪽이 Coordinator 라 장소 상세(``PlaceDetailNav/focusMyLocation``)와 같은 채널을 쓴다.
    case focusMyLocation(Coordinate)
}

public typealias RoomListStore = Store<RoomListState, RoomListAction, RoomListNav>

/// 개인방을 목록 맨 위로 올린다 — spec FR-004 "개인방(`내 장소`)이 최상단에 고정된 방 카드 목록".
///
/// 안정 분할(stable partition)이라 개인방끼리·공동방끼리의 서버 순서는 그대로 남는다.
/// 정렬 칩(전체/최근 저장 순/코멘트 순, FR-005)이 붙을 자리도 여기다 — 그 정렬은 공동방 구간에만
/// 걸고 개인방 고정은 유지해야 한다.
func personalFirst(_ rooms: [Room]) -> [Room] {
    rooms.filter { $0.type == .personal } + rooms.filter { $0.type != .personal }
}

/// 지금 고른 기준으로 지도 마커를 다시 받는다. 방 카드 목록은 건드리지 않는다 — 칩은 지도만 거른다.
///
/// 낸 조건을 응답(`.pinsLoaded(_:for:)`)에 함께 실어 늦게 온 응답을 버릴 수 있게 한다.
private func loadPins(
    _ state: RoomListState,
    fetchPins: FetchRoomPinsUseCase
) -> Effect<RoomListAction, RoomListNav> {
    let query = state.query
    let origin = state.myCoordinate
    return .run { send in
        // 마커 조회 실패는 알리지 않는다 — 시안에 이 실패를 알리는 UI 가 없고, 지도가 비는 것이
        // 곧 "못 받았다" 는 표시다(`.loaded` 의 `try?` 와 같은 판단).
        guard let pins = try? await fetchPins.execute(
            roomID: nil,
            sort: query.sort,
            category: query.category,
            origin: origin
        ) else { return }
        send(.pinsLoaded(pins, for: query))
    }
}

/// 순수 reduce. 의존성(UseCase)은 `Effect.run` 안에서만 사용하고 시그니처는 순수하게 유지한다.
public func roomListReducer(
    useCase: FetchRoomsUseCase,
    fetchPins: FetchRoomPinsUseCase,
    promptSnooze: SnoozeSwitch,
    currentLocation: CurrentLocationUseCase
) -> (inout RoomListState, RoomListAction) -> Effect<RoomListAction, RoomListNav> {
    { state, action in
        switch action {
        case .load:
            let query = state.query
            return .run { send in
                do {
                    // 방 목록과 지도 마커를 **병렬로** 받는다(MVI 절제 규칙: 병렬은 async let → 1 action).
                    async let rooms = useCase.execute()
                    // 마커는 실패해도 목록을 막지 않는다 — `try?` 로 받아 지도만 비운다.
                    // 방 목록이 이 화면의 본문이고 마커는 그 위에 얹는 것이라 운명을 묶지 않는다.
                    async let pins = try? fetchPins.execute(
                        roomID: nil,   // 내가 속한 모든 방 — PRD [SYS-004] "내 모든 방의 장소 마커"
                        sort: query.sort,
                        category: query.category,
                        origin: nil
                    )
                    send(.loaded(try await rooms, pins: await pins ?? [], isPromptSnoozed: promptSnooze.isSnoozed))
                } catch is CancellationError {
                    return   // 탭을 떠난 것 — 결과가 필요 없어진 것이라 실패가 아니다
                } catch let error as DomainError {
                    send(.loadFailed(error))
                } catch {
                    send(.loadFailed(.unknown))
                }
            }
        case .loaded(let rooms, let pins, let isPromptSnoozed):
            state.rooms = personalFirst(rooms)
            state.pins = pins

            // FR-007 — 방을 만들고 돌아온 길이면 목록만 갱신하고 그 방 상세로 넘어간다.
            // 유도 시트 판정은 건너뛴다(방을 막 만들었으니 띄울 이유도 없다).
            if let pending = state.pendingOpenRoomID {
                state.pendingOpenRoomID = nil
                if let room = state.room(id: pending) {
                    _ = state.consumeSkipFlag()
                    return .navigate(.openRoomDetail(room))
                }
            }
            // 기획: 활성 조건 = 공동방 미생성, 비활성 조건 = 공동방 1개 생성(001-2-1).
            // "나중에 만들래요" 를 누르면 2주 동안 뜨지 않는다(`SnoozeSwitch`).
            //
            // 단, 만들기 화면에서 돌아온 직후는 건너뛴다. pop 하면 이 화면의 `.task` 가 다시 돌아
            // `.load` 가 나가는데, 방금 그 시트에서 출발한 사용자에게 같은 시트를 즉시 다시 띄우게 된다
            // (시뮬레이터에서 재현). 취소하고 나온 경우엔 "나가기 → 시트 → 나가기" 가 반복된다.
            guard !state.consumeSkipFlag() else { return .none }
            state.isCreatePromptPresented = !state.hasSharedRoom && !isPromptSnoozed
            return .none
        case .loadFailed:
            // 실패도 Response Action 으로 받아 흘리지 않는다. 다만 에러 UI 는 범위 밖이라 표시는 하지 않는다.
            // 성공과 똑같이 플래그를 소비한다 — 실패 때 남겨 두면 다음 정상 진입이 조용히 막힌다.
            _ = state.consumeSkipFlag()
            return .none
        // FR-005 — 카드 목록 위 정렬 칩(전체/최근 저장 순/코멘트 순)은 아직 못 한다:
        // 방 목록 응답에 "마지막 저장 시각"도 "코멘트 수"도 없어 클라이언트에서 셀 수 없고
        // (`GET /api/v1/rooms` 응답 필드: pinCount·memberCount·createdAt·thumbnailList·users)
        // 서버에 정렬 파라미터도 없다. 그때까지 "전체"(서버 순서)만 실제로 동작한다.
        //
        // 아래 지도 위 드롭다운·칩과는 **다른 조작**이다 — 이쪽은 방 카드 목록, 저쪽은 지도 마커다.
        case .selectFilter(let index):
            state.filter = index
            return .none

        // 지도 위 드롭다운·칩(003-1 ①) — 마커를 다시 받는다. 방 카드 목록은 건드리지 않는다.
        case .selectRoomSort(let sort):
            // 거리순만 기준점을 필요로 한다. 좌표 없이 `sort=distance` 를 보내면 서버가 400 이다.
            guard sort.requiresOrigin, state.myCoordinate == nil else {
                state.isLocatingForSort = false   // 기다리던 거리순 선택이 있었다면 접는다
                guard sort != state.roomSort else { return .none }
                state.roomSort = sort
                return loadPins(state, fetchPins: fetchPins)
            }
            guard !state.isLocatingForSort else { return .none }
            state.isLocatingForSort = true
            return .run { send in
                let result = await currentLocation.execute()
                guard !Task.isCancelled else { return }
                send(.sortLocationResolved(result))
            }
        case .sortLocationResolved(let result):
            // 기다리는 사이 다른 정렬을 골랐다면 늦게 온 좌표로 그 선택을 뒤집지 않는다.
            guard state.isLocatingForSort else { return .none }
            state.isLocatingForSort = false
            // 좌표를 못 얻으면 정렬은 고르기 전 값 그대로 둔다 — 라벨만 "거리순" 인 거짓 상태를
            // 만들지 않는다(방 상세와 같은 규칙). 시안에 이 실패를 알리는 UI 가 없다.
            guard case .coordinate(let coordinate) = result else { return .none }
            state.myCoordinate = coordinate
            state.roomSort = .distance
            return loadPins(state, fetchPins: fetchPins)
        case .selectCategory(let category):
            guard category != state.category else { return .none }
            state.category = category
            return loadPins(state, fetchPins: fetchPins)
        case .pinsLoaded(let pins, let query):
            // 늦게 온 응답은 버린다 — 그사이 다른 기준을 골랐다면 지금 화면과 다른 마커다.
            guard query == state.query else { return .none }
            state.pins = pins
            return .none
        // PRD 「지연 권한 요청」 — "위치 권한을 묻는 맥락은 세 곳이다 — **지도가 실제로 그려지는
        // 시점(저장 탭 최초 진입)**, 홈 탭 `가까운순` 전환, 마이페이지 `위치 설정` 스위치" /
        // "탭 진입 ➔ 지도 초기화(**위치 권한이 아직 없을 때만 이 시점에 요청** — 이미 허용됐다면
        // 묻지 않는다)".
        //
        // 좌표를 이미 들고 있으면 물어본 적이 있다는 뜻이라 넘어간다. `CurrentLocationUseCase` 가
        // 이미 거부된 상태면 팝업 없이 `permissionDenied` 로 돌아오므로, 거부한 사용자를 탭마다
        // 다시 괴롭히지도 않는다.
        case .requestLocationOnEntry:
            guard state.myCoordinate == nil, !state.isLocating, !state.isLocatingForSort else {
                return .none
            }
            return .run { send in
                let result = await currentLocation.execute()
                guard !Task.isCancelled else { return }
                send(.entryLocationResolved(result))
            }
        case .entryLocationResolved(let result):
            // **카메라를 옮기지 않는다.** 진입 시 하는 일은 권한 확보와 좌표 확보까지다 —
            // 지도를 내 위치로 끌어가는 것은 사용자가 현위치 버튼을 눌렀을 때의 동작이다.
            // 거부·측위 실패도 조용히 지나간다: PRD "거부: 기본 디폴트 좌표를 중심점으로 세팅"
            // 이고 그 기본 카메라(`PlaceMap.defaultCamera`, 강남)가 이미 기본값이다.
            guard case .coordinate(let coordinate) = result else { return .none }
            state.myCoordinate = coordinate
            return .none
        case .tapPin(let pinID):
            // 목록에 없는 id 는 무시한다 — 마커를 지우는 사이 들어온 탭이다.
            guard let pin = state.pins.first(where: { $0.id.value == pinID }) else { return .none }
            return .navigate(.openPlaceDetail(pin))
        case .tapRoom(let room):
            return .navigate(.openRoomDetail(room))
        case .tapCreateRoom:
            state.isCreatePromptPresented = false
            state.skipsNextCreatePrompt = true
            return .navigate(.goToCreateRoom)

        // FR-007. 재조회가 이미 끝나 있으면(공유 시트 경로처럼 목록이 살아 있는 경우) 바로 열고,
        // 아직이면 예약해 두었다가 `.loaded` 에서 연다 — 둘 중 무엇이 먼저 와도 같게 동작한다.
        case .openCreatedRoom(let roomID):
            if let room = state.room(id: roomID) {
                return .navigate(.openRoomDetail(room))
            }
            state.pendingOpenRoomID = roomID
            return .none
        // "나중에 만들래요" 만 미룬다. 스와이프로 내린 건 실수일 수 있어 2주를 걸지 않는다.
        case .tapLater:
            state.isCreatePromptPresented = false
            return .run { _ in promptSnooze.snooze() }
        case .dismissCreatePrompt:
            state.isCreatePromptPresented = false
            return .none

        // 003-1 ⑦ — 권한 미결정이면 유스케이스가 그 자리에서 묻고, 이미 거부됐으면 묻지 않고
        // `permissionDenied` 로 돌아온다. 좌표를 못 얻으면 아무것도 하지 않는다: 시안에 실패를
        // 알리는 UI 가 없고, 지도는 기본 카메라(강남 일대, ``PlaceMap/defaultCamera``)에 머문다
        // — 003-1 ⑦ "최초 접속 시 거절, 클릭 후 거절 시 사용자 기본 위치는 '강남역'".
        // 장소 상세의 같은 버튼(``PlaceDetailStore`` 의 `.tapMyLocation`)과 같은 규칙이다.
        case .tapMyLocation:
            guard !state.isLocating else { return .none }
            state.isLocating = true
            return .run { send in
                let result = await currentLocation.execute()
                // 화면을 떠나 취소된 것 — 결과가 필요 없어진 것이라 state 를 갱신하지 않는다.
                guard !Task.isCancelled else { return }
                send(.myLocationResolved(result))
            }
        case .myLocationResolved(let result):
            state.isLocating = false
            guard case .coordinate(let coordinate) = result else { return .none }
            return .navigate(.focusMyLocation(coordinate))
        }
    }
}
