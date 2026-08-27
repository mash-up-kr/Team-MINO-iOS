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
}

enum RoomDetailAction: Equatable {
    case load
    case loaded([Pin])
    case loadFailed(DomainError)
    case selectSort(RoomDetailSort)
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
}

typealias RoomDetailStore = Store<RoomDetailState, RoomDetailAction, RoomDetailNav>

func roomDetailReducer(
    useCase: FetchPinsUseCase,
    deletePin: DeletePinUseCase,
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

        case .selectSort(let sort):
            state.sort = sort
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
    state.locations = RoomDetailSorting.apply(state.sort, to: filtered, now: now)
        .map(RoomDetailLocation.init(from:))
}
