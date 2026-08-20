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
}

enum RoomDetailNav: Equatable, Sendable {
    case close
    case shareLocation(RoomDetailLocation)
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
        }
    }
}

private func applySort(_ state: inout RoomDetailState, now: Date) {
    state.locations = RoomDetailSorting.apply(state.sort, to: state.pins, now: now)
        .map(RoomDetailLocation.init(from:))
}
