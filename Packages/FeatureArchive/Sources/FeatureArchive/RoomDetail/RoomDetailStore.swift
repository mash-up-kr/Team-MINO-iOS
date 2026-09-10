import Domain
import Foundation
import MVI

struct RoomDetailState: Equatable {
    var room: RoomDetailRoom
    var pins: [Pin] = []
    var locations: [RoomDetailLocation] = []
    /// 고른 정렬 기준. **서버가 이 값으로 정렬해 준다** — 화면은 받은 순서를 그대로 그린다.
    var sort: PinSort = .all
    /// 고른 카테고리 칩. 목록은 고정 3종이라 state 가 들지 않는다(``PlaceCategoryFilter/allCases``).
    var category: PlaceCategoryFilter = .all
    var viewMode: RoomDetailViewMode = .list
    /// 장소 삭제 확인 다이얼로그(004-1-3-1). nil 이면 닫혀 있다.
    var deletion: RoomDetailDeletion?
    /// 방 나가기 확인 다이얼로그(004-5). nil 이면 닫혀 있다.
    var leave: RoomDetailLeave?
    /// 방장 위임 대상 고르기. 나가기가 409 로 거절됐을 때만 선다 — 두 상태는 이어 달리므로
    /// 동시에 서지 않는다(409 를 받는 순간 ``leave`` 를 내리고 이쪽을 세운다).
    var ownerTransfer: RoomOwnerTransfer?
    /// 내가 이 방의 방장인가 — 헤더 케밥에 "방 편집" 을 붙일지의 유일한 기준(004-1 ② 2-2).
    ///
    /// 신원을 아직 못 받았거나 조회에 실패하면 `false` 로 남는다. 모르는 쪽을 "방장 아님" 으로
    /// 두어야 남의 방에 편집 항목이 붙는 사고가 나지 않는다.
    var isOwner = false
    var isLoadingCurrentMember = false
    /// 거리순(004-1 ⑥)의 기준점인 내 위치. 한 번 받아 두고 이 화면이 사는 동안 다시 묻지 않는다 —
    /// 3km 를 가르는 값이라, 시트를 열어 둔 사이에 사람이 그만큼 움직이지는 않는다.
    var myCoordinate: Coordinate?
    /// 거리순 선택이 내 위치를 기다리는 중.
    ///
    /// 좌표가 서기 전에는 `sort` 를 `.distance` 로 세우지 않으므로 "거리순을 눌렀다" 는 사실이
    /// 여기에만 남는다. 그 사이 다른 정렬을 고르면 여기서 내려, 늦게 도착한 좌표가 사용자의
    /// 새 선택을 뒤집지 않게 한다.
    var isLocating = false
    /// 헤더 케밥 드롭다운(004-5)이 열려 있는가.
    ///
    /// 장소 카드 케밥은 열림 상태를 View 가 들지만 이건 reduce 가 든다. peek 에서 이 메뉴는 시트
    /// **위**(지도 위)로 떠야 하는데 시트는 콘텐츠를 잘라내므로(``MHBottomSheet`` 의 clipShape)
    /// 그림은 시트 밖에서 그린다 — 버튼을 가진 뷰와 그리는 뷰가 갈라져 공통 진실이 필요하다.
    var isMoreMenuPresented = false

    /// 지금 화면이 고른 조회 조건. 요청을 낼 때와 응답을 받아들일지 판단할 때 같은 값을 봐야 해서
    /// 한자리에서 만든다.
    var query: PinQuery { PinQuery(sort: sort, category: category) }
}

enum RoomDetailAction: Equatable {
    case load
    /// 조회 결과. **어떤 조건으로 낸 요청인지 함께 실어** 늦게 온 응답을 버릴 수 있게 한다.
    case loaded([Pin], for: PinQuery)
    case loadFailed(DomainError)
    case loadCurrentMember
    case currentMemberLoaded(MemberProfile)
    case currentMemberLoadFailed(DomainError)
    case tapAddMember
    case tapMore
    case dismissMoreMenu
    case selectMoreMenuItem(RoomDetailMoreMenuItemID)
    case selectSort(PinSort)
    case locationResolved(CurrentLocationResult)
    case selectCategory(PlaceCategoryFilter)
    case selectViewMode(RoomDetailViewMode)
    case tapClose
    case tapShare(RoomDetailLocation)
    case tapLocation(RoomDetailLocation.ID)
    case tapDeleteLocation(RoomDetailLocation.ID)
    case cancelDelete
    case confirmDelete
    case deleted(PinID)
    case deleteFailed(DomainError)
    case cancelLeave
    case confirmLeave
    /// 나가기가 끝났다(위임을 거친 경우도 여기로 모인다).
    case leaveSucceeded
    case leaveFailed(DomainError)
    case selectNextOwner(String)
    case cancelOwnerTransfer
    case confirmOwnerTransfer
}

enum RoomDetailNav: Equatable, Sendable {
    case close
    case shareLocation(RoomDetailLocation)
    case openPlaceDetail(Pin)
    /// 헤더 아바타 옆 `+`(004-1 ② 2-1) → `004-4-2_친구 초대 클릭` 시트.
    ///
    /// 표시 모델(`RoomDetailRoom`)이 아니라 도메인 `Room` 을 싣는다 — 시트가 참여자 닉네임과 방 색을
    /// 함께 쓰는데 표시 모델은 아바타 색만 남기고 나머지를 버린다(``RoomDetailRoom/init(from:)``).
    case inviteFriends(Room)
    /// 헤더 케밥 "방 편집" (방장만) → `ArchiveRoute.editRoom`.
    case editRoom(Room)
    /// 이 방에서 나갔다 — 방 상세를 닫고 목록을 다시 받으라는 뜻.
    ///
    /// 확인·위임까지가 이 화면 안의 일이라(``RoomDetailLeave``·``RoomOwnerTransfer``) 밖으로는
    /// **끝난 사실만** 나간다. "나가기를 눌렀다" 를 내보내면 flow 마다 확인 절차를 다시 짜야 한다.
    case didLeaveRoom
}

typealias RoomDetailStore = Store<RoomDetailState, RoomDetailAction, RoomDetailNav>

func roomDetailReducer(
    useCase: FetchRoomPinsUseCase,
    deletePin: DeletePinUseCase,
    fetchCurrentMember: CurrentMemberUseCase,
    currentLocation: CurrentLocationUseCase,
    leaveRoom: LeaveRoomUseCase,
    transferRoomOwner: TransferRoomOwnerUseCase,
    room: Room
) -> (inout RoomDetailState, RoomDetailAction) -> Effect<RoomDetailAction, RoomDetailNav> {
    { state, action in
        switch action {
        case .load:
            return loadPins(state, room: room, useCase: useCase)

        case .loaded(let pins, let query):
            // 늦게 온 응답은 버린다 — 그사이 다른 기준을 골랐다면 지금 화면과 다른 목록이다.
            guard query == state.query else { return .none }
            state.pins = pins
            state.locations = pins.map(RoomDetailLocation.init(from:))
            return .none

        case .loadFailed:
            return .none

        // 장소 조회와 한 effect 로 묶지 않는다 — 한쪽 실패가 다른 쪽 결과까지 끌고 내려갈 이유가 없다.
        case .loadCurrentMember:
            guard !state.isLoadingCurrentMember else { return .none }
            state.isLoadingCurrentMember = true
            return .run { send in
                do {
                    send(.currentMemberLoaded(try await fetchCurrentMember.execute()))
                } catch is CancellationError {
                    return   // 화면을 떠난 것 — 실패가 아니다
                } catch {
                    send(.currentMemberLoadFailed(error as? DomainError ?? .unknown))
                }
            }

        case .currentMemberLoaded(let profile):
            // 방장 판정은 뷰가 아니라 여기서 한다 — 신원과 방 주인을 맞대 보는 건 도메인 규칙이다.
            state.isOwner = profile.id.value == room.ownerId
            state.isLoadingCurrentMember = false
            return .none

        case .currentMemberLoadFailed:
            // 신원을 모르면 방장이 아닌 쪽으로 남는다 — 오류 UI 없이 "방 편집" 만 안 붙는다.
            state.isLoadingCurrentMember = false
            return .none

        case .tapAddMember:
            // 개인방은 초대 불가(PRD 「개인방」 · [SYS-006] "공동방에 타인을 초대할 때").
            // 헤더가 `+` 를 그리지 않으므로 평소엔 오지 않는 길이지만, 오더라도 열지 않는다 —
            // 개인방 초대 링크가 나가면 "혼자만의 공간" 이라는 방 종류의 정의가 깨진다.
            guard room.type == .shared else { return .none }
            return .navigate(.inviteFriends(room))

        case .tapMore:
            // 개인방은 더보기 자체가 없다(시안 `004-5` Case 3) — 위와 같은 이유로 방어한다.
            guard room.type == .shared else { return .none }
            state.isMoreMenuPresented.toggle()
            return .none

        case .dismissMoreMenu:
            state.isMoreMenuPresented = false
            return .none

        case .selectMoreMenuItem(let item):
            state.isMoreMenuPresented = false
            switch item {
            case .editRoom:
                // 방장이 아니면 항목 자체가 없지만, 노출 판정을 뷰에만 맡기지 않는다.
                guard state.isOwner else { return .none }
                return .navigate(.editRoom(room))
            case .leaveRoom:
                // 나가면 방이 사라지는 경우인지 여기서 가른다 — 문구가 갈린다. 최종 판단은
                // 서버가 하고(방장+마지막 멤버면 방 삭제), 여기서는 가진 값으로 미리 알린다.
                state.leave = RoomDetailLeave(deletesRoom: state.isOwner && room.memberCount <= 1)
                return .none
            }

        case .selectSort(let sort):
            // 거리순만 기준점을 필요로 한다. 아직 없으면 **선택을 세우지 않고** 좌표부터 받는다 —
            // 좌표 없이 `sort=distance` 를 보내면 서버가 400(`VALIDATION_ERROR`)으로 거절한다.
            guard sort.requiresOrigin, state.myCoordinate == nil else {
                state.isLocating = false   // 기다리던 거리순 선택이 있었다면 접는다
                // 같은 기준을 다시 골랐으면 요청을 내지 않는다 — 결과가 같은데 목록만 깜박인다.
                guard sort != state.sort else { return .none }
                state.sort = sort
                return loadPins(state, room: room, useCase: useCase)
            }
            // 연타로 위치 요청(과 시스템 팝업)을 두 번 내보내지 않는다.
            guard !state.isLocating else { return .none }
            state.isLocating = true
            return .run { send in
                let result = await currentLocation.execute()
                // 화면을 떠나 취소된 것 — 실패가 아니라 결과가 필요 없어진 것이다.
                // (유스케이스가 throw 하지 않아 `catch is CancellationError` 대신 여기서 거른다)
                guard !Task.isCancelled else { return }
                send(.locationResolved(result))
            }

        case .locationResolved(let result):
            // 기다리는 사이 다른 정렬을 골랐다면 늦게 온 좌표로 그 선택을 뒤집지 않는다.
            guard state.isLocating else { return .none }
            state.isLocating = false

            guard case .coordinate(let coordinate) = result else {
                // 좌표를 못 얻었다(권한 거부 · 측위 실패). 정렬은 고르기 전 값 그대로 두고 목록도
                // 손대지 않는다 — `.distance` 를 세워 두면 라벨만 "거리순" 이고 목록은 원본이라
                // 거짓말이 된다. 드롭다운이 그대로인 것이 곧 "거리순이 걸리지 않았다" 는 표시다
                // (`.deleteFailed` 와 같은 결).
                //
                // 시안 004-1 에는 이 실패를 알리는 화면(토스트·안내·설정 앱 유도)이 **없다**.
                // 없는 UI 를 지어내지 않고, `CurrentLocationResult` 가 사유(`permissionDenied` /
                // `unavailable`)를 구분해 오므로 안내 화면이 정해지면 여기서 갈라 쓰면 된다.
                return .none
            }
            state.myCoordinate = coordinate
            state.sort = .distance
            return loadPins(state, room: room, useCase: useCase)

        case .selectCategory(let category):
            guard category != state.category else { return .none }
            state.category = category
            return loadPins(state, room: room, useCase: useCase)

        case .selectViewMode(let mode):
            state.viewMode = mode
            return .none

        case .tapClose:
            return .navigate(.close)

        case .tapShare(let location):
            return .navigate(.shareLocation(location))

        case .tapLocation(let id):
            guard let pin = state.pins.first(where: { $0.id.value == id }) else { return .none }
            return .navigate(.openPlaceDetail(pin))

        case .tapDeleteLocation(let id):
            state.deletion = RoomDetailDeletion(locationID: id)
            return .none

        case .cancelDelete:
            state.deletion = nil
            return .none

        case .confirmDelete:
            // 이미 보낸 요청이 있으면 무시한다 — 확인 버튼은 잠기지만 접근성 조작 등으로 두 번 들어올 수 있다.
            guard let deletion = state.deletion, !deletion.isSubmitting,
                  let pin = state.pins.first(where: { $0.id.value == deletion.locationID })
            else { return .none }

            state.deletion?.isSubmitting = true
            return .run { send in
                do {
                    try await deletePin.execute(pinID: pin.id)
                    send(.deleted(pin.id))
                } catch is CancellationError {
                    return   // 화면을 떠나 취소된 것 — 실패가 아니라 결과가 필요 없어진 것이다
                } catch {
                    send(.deleteFailed(error as? DomainError ?? .unknown))
                }
            }

        case .deleted(let pinID):
            state.deletion = nil
            // 같은 삭제로 두 번 들어오면 카운트만 또 줄어든다 — 실제로 뺄 게 있을 때만 진행한다.
            guard state.pins.contains(where: { $0.id == pinID }) else { return .none }
            state.pins.removeAll { $0.id == pinID }
            state.room = state.room.removingOneLocation()
            // 재조회하지 않는다 — 남은 핀의 순서는 이미 서버가 정해 준 그 순서다.
            state.locations = state.pins.map(RoomDetailLocation.init(from:))
            return .none

        case .deleteFailed:
            // 실패 피드백(토스트)은 시안 004-1-3-1 에 없다. 다이얼로그만 닫고 목록은 손대지 않는다 —
            // 지우려던 장소가 그 자리에 남아 있는 것이 곧 "안 지워졌다"는 표시다.
            state.deletion = nil
            return .none

        // MARK: 방 나가기 (004-5)

        case .cancelLeave:
            state.leave = nil
            return .none

        case .confirmLeave:
            guard let leave = state.leave, !leave.isSubmitting else { return .none }
            state.leave?.isSubmitting = true
            state.leave?.failed = false
            return .run { send in
                do {
                    try await leaveRoom.execute(roomId: room.id)
                    send(.leaveSucceeded)
                } catch is CancellationError {
                    return   // 화면을 떠난 것 — 실패가 아니다
                } catch {
                    send(.leaveFailed(error as? DomainError ?? .roomLeaveFailed))
                }
            }

        case .leaveSucceeded:
            state.leave = nil
            state.ownerTransfer = nil
            return .navigate(.didLeaveRoom)

        // 409 는 실패가 아니라 **다음 절차의 요구**다 — 안내 대신 새 방장 고르기로 넘어간다.
        case .leaveFailed(.ownerTransferRequired):
            state.leave = nil
            let candidates = room.users
                .filter { $0.userId != room.ownerId }
                .map {
                    RoomOwnerTransferCandidate(
                        id: $0.userId, nickname: $0.nickname, avatarColor: $0.avatarColor
                    )
                }
            // 넘길 사람이 없는데 서버가 위임을 요구했다 — 손에 든 멤버 목록이 낡았다는 뜻이다
            // (그 사이 다른 사람이 들어왔다). 빈 목록을 띄우면 빠져나갈 길이 없어, 대신 나가기
            // 다이얼로그를 실패 상태로 되돌려 다시 시도할 수 있게 둔다.
            guard !candidates.isEmpty else {
                state.leave = RoomDetailLeave(deletesRoom: false, failed: true)
                return .none
            }
            state.ownerTransfer = RoomOwnerTransfer(candidates: candidates)
            return .none

        case .leaveFailed:
            // 다이얼로그를 닫지 않는다 — 닫으면 "눌렀는데 아무 일도 없다" 로 보인다.
            // 문구만 바꿔(``RoomDetailLeave/failed``) 그 자리에서 다시 시도하게 한다.
            if state.ownerTransfer != nil {
                state.ownerTransfer?.isSubmitting = false
                state.ownerTransfer?.failed = true
            } else {
                state.leave?.isSubmitting = false
                state.leave?.failed = true
            }
            return .none

        case .selectNextOwner(let userID):
            guard state.ownerTransfer?.isSubmitting == false else { return .none }
            state.ownerTransfer?.selectedID = userID
            return .none

        case .cancelOwnerTransfer:
            state.ownerTransfer = nil
            return .none

        case .confirmOwnerTransfer:
            guard let transfer = state.ownerTransfer, transfer.canSubmit,
                  let nextOwnerID = transfer.selectedID
            else { return .none }
            state.ownerTransfer?.isSubmitting = true
            state.ownerTransfer?.failed = false
            return .run { send in
                do {
                    // 위임과 나가기는 **한 동작**이다 — 사용자가 고른 건 "넘기고 나가기" 하나다.
                    // 위임만 성공하고 멈추면 방장이 바뀐 채 그대로 남아 되돌릴 방법이 없다.
                    try await transferRoomOwner.execute(roomId: room.id, nextOwnerId: nextOwnerID)
                    try await leaveRoom.execute(roomId: room.id)
                    send(.leaveSucceeded)
                } catch is CancellationError {
                    return
                } catch {
                    send(.leaveFailed(error as? DomainError ?? .ownerTransferFailed))
                }
            }
        }
    }
}

/// 지금 고른 기준으로 목록을 다시 받는다. 조회는 `.load` 와 기준 변경이 함께 쓰는 길이라
/// 한자리에 둔다 — 조건을 싣는 것을 한쪽에서 빠뜨리면 화면과 요청이 어긋난다.
///
/// 낸 조건을 응답(`.loaded(_:for:)`)에 함께 실어 늦게 온 응답을 버릴 수 있게 한다.
private func loadPins(
    _ state: RoomDetailState,
    room: Room,
    useCase: FetchRoomPinsUseCase
) -> Effect<RoomDetailAction, RoomDetailNav> {
    let query = state.query
    let origin = state.myCoordinate
    return .run { send in
        do {
            let pins = try await useCase.execute(
                roomID: room.id,
                sort: query.sort,
                category: query.category,
                origin: origin
            )
            send(.loaded(pins, for: query))
        } catch is CancellationError {
            // 화면을 떠났거나 새 기준으로 다시 요청한 것 — 결과가 필요 없어진 것이라 실패가 아니다.
            // 기준을 바꿀 때마다 요청이 나가므로 이 갈래가 실제로 자주 밟힌다.
            return
        } catch let error as DomainError {
            send(.loadFailed(error))
        } catch {
            send(.loadFailed(.unknown))
        }
    }
}
