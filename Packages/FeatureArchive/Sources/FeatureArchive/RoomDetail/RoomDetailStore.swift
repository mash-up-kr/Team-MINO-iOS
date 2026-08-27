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
}

enum RoomDetailNav: Equatable, Sendable {
    case close
    case shareLocation(RoomDetailLocation)
    case openPlaceDetail(Pin)
}

typealias RoomDetailStore = Store<RoomDetailState, RoomDetailAction, RoomDetailNav>

func roomDetailReducer(
    useCase: FetchPinsUseCase,
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
            state.categories = RoomDetailCategoryList.make(from: pins)
            // 고르고 있던 업종이 재조회로 사라지면 빈 목록이 남는다 — "전체" 로 되돌린다.
            if !state.categories.contains(state.category) {
                state.category = RoomDetailCategoryList.all
            }
            applyFilters(&state, now: now())
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
        }
    }
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
