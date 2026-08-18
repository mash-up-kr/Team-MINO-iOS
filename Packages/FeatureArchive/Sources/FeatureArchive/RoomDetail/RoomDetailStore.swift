import Domain
import Foundation
import MVI

struct RoomDetailState: Equatable {
    var room: RoomDetailRoom
    var pins: [Pin] = []
    var locations: [RoomDetailLocation] = []
    var sort: RoomDetailSort = .all
    var category: RoomDetailCategory = .all
    var viewMode: RoomDetailViewMode = .list
}

enum RoomDetailAction: Equatable {
    case load
    case loaded([Pin])
    case loadFailed(DomainError)
    case selectSort(RoomDetailSort)
    case selectCategory(RoomDetailCategory)
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
                    let pins = try await useCase.execute(room: room, page: 0)
                    send(.loaded(pins))
                } catch let error as DomainError {
                    send(.loadFailed(error))
                } catch {
                    send(.loadFailed(.unknown))
                }
            }

        case .loaded(let pins):
            state.pins = pins
            applySort(&state, now: now())
            return .none

        case .loadFailed:
            return .none

        case .selectSort(let sort):
            state.sort = sort
            applySort(&state, now: now())
            return .none

        case .selectCategory(let category):
            state.category = category
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

/// 화면의 정렬 선택지를 도메인 정책(PinCuration)으로 dispatch 한다.
/// 거리순·코멘트순은 계산 근거(좌표·코멘트 수)가 아직 없어 원본을 그대로 낸다.
private func applySort(_ state: inout RoomDetailState, now: Date) {
    let sorted: [Pin]
    switch state.sort {
    case .all, .distance, .comment:
        sorted = state.pins
    case .pick:
        sorted = PinCuration.pick(from: state.pins)
    case .latest:
        sorted = PinCuration.latest(from: state.pins, now: now)
    }
    state.locations = sorted.map(RoomDetailLocation.init(from:))
}
