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
    room: Room
) -> (inout RoomDetailState, RoomDetailAction) -> Effect<RoomDetailAction, RoomDetailNav> {
    { state, action in
        switch action {
        case .load:
            return .run { send in
                do {
                    // 방 상세는 서버 조회 기준이 없다 — 목록 정렬은 도메인 정책(PinCuration)을 Feature 가
                    // dispatch 해 클라이언트에서 하고, `PinFilter` 는 홈 카드 덱의 칩(꾹 Pick/최신순/가까운순)
                    // 개념이다. 기본 기준으로 받아온다.
                    let pins = try await useCase.execute(roomID: room.id, page: 0, filter: .recommended)
                    send(.loaded(pins))
                } catch let error as DomainError {
                    send(.loadFailed(error))
                } catch {
                    send(.loadFailed(.unknown))
                }
            }

        case .loaded(let pins):
            state.pins = pins
            applySort(&state)
            return .none

        case .loadFailed:
            return .none

        case .selectSort(let sort):
            state.sort = sort
            applySort(&state)
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
private func applySort(_ state: inout RoomDetailState) {
    let sorted: [Pin]
    switch state.sort {
    case .all, .distance, .comment:
        sorted = state.pins
    case .pick:
        sorted = PinCuration.pick(from: state.pins)
    case .latest:
        sorted = PinCuration.latest(from: state.pins)
    }
    state.locations = sorted.map(RoomDetailLocation.init(from:))
}
