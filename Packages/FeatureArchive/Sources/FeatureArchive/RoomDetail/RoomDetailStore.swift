import Domain
import Foundation
import MVI

struct RoomDetailState: Equatable {
    var room: RoomDetailRoom
    var pins: [Pin] = []
    var locations: [RoomDetailLocation] = []
    var sort: RoomDetailSort = .all
    /// 방에 담긴 장소들의 업종에서 만들어진다(004-1 ⑨). 첫 칸은 항상 "전체".
    var categories: [String] = [RoomDetailCategoryList.all]
    var category: String = RoomDetailCategoryList.all
    var viewMode: RoomDetailViewMode = .list
    /// 장소 삭제 확인 다이얼로그(004-1-3-1). nil 이면 닫혀 있다.
    var deletion: RoomDetailDeletion?
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
}

enum RoomDetailAction: Equatable {
    case load
    case loaded([Pin])
    case loadFailed(DomainError)
    case loadCurrentMember
    case currentMemberLoaded(MemberProfile)
    case currentMemberLoadFailed(DomainError)
    case tapMore
    case dismissMoreMenu
    case selectMoreMenuItem(RoomDetailMoreMenuItemID)
    case selectSort(RoomDetailSort)
    case locationResolved(CurrentLocationResult)
    case selectCategory(String)
    case selectViewMode(RoomDetailViewMode)
    case tapClose
    case tapShare(RoomDetailLocation)
    case tapLocation(RoomDetailLocation.ID)
    case tapDeleteLocation(RoomDetailLocation.ID)
    case cancelDelete
    case confirmDelete
    case deleted(PinID)
    case deleteFailed(DomainError)
}

enum RoomDetailNav: Equatable, Sendable {
    case close
    case shareLocation(RoomDetailLocation)
    case openPlaceDetail(Pin)
    /// 헤더 케밥 "방 편집" (방장만). 도착 화면은 아직 없다 — `ArchiveCoordinator.handle(_: RoomDetailNav)` 참조.
    case editRoom(Room)
    /// 헤더 케밥 "방 나가기". 도착 화면은 아직 없다 — 위와 같다.
    case leaveRoom(Room)
}

typealias RoomDetailStore = Store<RoomDetailState, RoomDetailAction, RoomDetailNav>

func roomDetailReducer(
    useCase: FetchPinsUseCase,
    deletePin: DeletePinUseCase,
    fetchCurrentMember: CurrentMemberUseCase,
    currentLocation: CurrentLocationUseCase,
    room: Room,
    now: @escaping () -> Date = Date.init
) -> (inout RoomDetailState, RoomDetailAction) -> Effect<RoomDetailAction, RoomDetailNav> {
    { state, action in
        switch action {
        case .load:
            return .run { send in
                do {
                    // 방 상세는 서버 조회 기준이 없다 — 목록 정렬은 `RoomDetailSorting` 이 클라이언트에서 하고
                    // `PinFilter` 는 홈 카드 덱의 칩(꾹 Pick/최신순/가까운순) 개념이다. 기본 기준으로 받아온다.
                    let pins = try await useCase.execute(room: room, page: 0, filter: .recommended)
                    send(.loaded(pins))
                } catch let error as DomainError {
                    send(.loadFailed(error))
                } catch {
                    send(.loadFailed(.unknown))
                }
            }

        case .loaded(let pins):
            state.pins = pins
            applyPins(&state, now: now())
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

        case .tapMore:
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
                return .navigate(.leaveRoom(room))
            }

        case .selectSort(let sort):
            // 거리순만 기준점을 필요로 한다. 아직 없으면 **선택을 세우지 않고** 좌표부터 받는다 —
            // 좌표 없이 `.distance` 를 세우면 라벨은 "거리순" 인데 목록은 3km 와 무관한 원본이다.
            guard sort == .distance, state.myCoordinate == nil else {
                state.isLocating = false   // 기다리던 거리순 선택이 있었다면 접는다
                state.sort = sort
                applyFilters(&state, now: now())
                return .none
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
            applyFilters(&state, now: now())
            return .none

        case .selectCategory(let category):
            state.category = category
            applyFilters(&state, now: now())
            return .none

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
            applyPins(&state, now: now())
            return .none

        case .deleteFailed:
            // 실패 피드백(토스트)은 시안 004-1-3-1 에 없다. 다이얼로그만 닫고 목록은 손대지 않는다 —
            // 지우려던 장소가 그 자리에 남아 있는 것이 곧 "안 지워졌다"는 표시다.
            state.deletion = nil
            return .none
        }
    }
}

/// 원본(`pins`)이 바뀌면 칩 목록과 표시 목록을 함께 다시 맞춘다.
///
/// 조회와 삭제가 같은 자리를 쓴다. 삭제만 `locations` 를 직접 손보면 방금 지운 장소가
/// 업종 칩에는 남고, 그 칩을 누르면 빈 목록이 뜬다 — 원본에서 다시 파생시켜 어긋날 자리를 없앤다.
private func applyPins(_ state: inout RoomDetailState, now: Date) {
    state.categories = RoomDetailCategoryList.make(from: state.pins)
    // 고르고 있던 업종이 사라지면(재조회·마지막 장소 삭제) 빈 목록이 남는다 — "전체" 로 되돌린다.
    if !state.categories.contains(state.category) {
        state.category = RoomDetailCategoryList.all
    }
    applyFilters(&state, now: now)
}

/// 업종 칩으로 거르고 정렬 드롭다운으로 줄을 세운 결과가 화면 목록이다.
///
/// 거르기가 먼저다. "꾹 Pick"·"코멘트순" 처럼 **상위 30%만 남기는** 기준은 모수가 바뀌면 결과도
/// 바뀌는데, 사용자가 카페 칩을 눌렀다면 그 30% 는 카페 안에서의 30% 여야 한다.
private func applyFilters(_ state: inout RoomDetailState, now: Date) {
    let filtered = RoomDetailCategoryList.filter(state.pins, by: state.category)
    state.locations = RoomDetailSorting.apply(state.sort, to: filtered, now: now, from: state.myCoordinate)
        .map(RoomDetailLocation.init(from:))
}
