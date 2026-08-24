import Domain
import MVI

/// 방 리스트 화면 상태 — 단일 `Equatable` struct.
/// 빈/로딩/에러 UI 는 이번 범위 밖(screen.md)이라 로딩 플래그를 두지 않는다.
public struct RoomListState: Equatable {
    public var rooms: [Room]
    /// 선택된 필터 칩 인덱스(전체/최근 저장 순/코멘트 순). 정렬 로직은 미구현(UI 상태만).
    public var filter: Int
    public var roomFilter: Int
    public var categoryFilter: Int

    public init(rooms: [Room] = [], filter: Int = 0, roomFilter: Int = 0, categoryFilter: Int = 0) {
        self.rooms = rooms
        self.filter = filter
        self.roomFilter = roomFilter
        self.categoryFilter = categoryFilter
    }
}

public enum RoomListAction: Equatable {
    case load
    case loaded([Room])            // Response Action (성공)
    case loadFailed(DomainError)   // Response Action (실패)
    case selectFilter(Int)
    case selectRoomFilter(Int)
    case selectCategory(Int)
    case tapRoom(Room)
}

public enum RoomListNav: Equatable, Sendable {
    case openRoomDetail(Room)
}

public typealias RoomListStore = Store<RoomListState, RoomListAction, RoomListNav>

/// 순수 reduce. 의존성(UseCase)은 `Effect.run` 안에서만 사용하고 시그니처는 순수하게 유지한다.
public func roomListReducer(
    useCase: FetchRoomsUseCase
) -> (inout RoomListState, RoomListAction) -> Effect<RoomListAction, RoomListNav> {
    { state, action in
        switch action {
        case .load:
            return .run { send in
                do {
                    let rooms = try await useCase.execute()
                    send(.loaded(rooms))
                } catch let error as DomainError {
                    send(.loadFailed(error))
                } catch {
                    send(.loadFailed(.unknown))
                }
            }
        case .loaded(let rooms):
            state.rooms = rooms
            // 방 필터 옵션은 화면에서 `["전체"] + rooms` 로 만들어지므로 유효 인덱스 상한이
            // rooms.count 다. 방이 줄어든 재조회 뒤 옛 인덱스가 남으면 옵션 배열을 넘어
            // 크래시한다(MHFilterBar 가 sortOptions[selectedSort] 로 라벨을 읽는다).
            state.roomFilter = min(state.roomFilter, rooms.count)
            return .none
        case .loadFailed:
            // 실패도 Response Action 으로 받아 흘리지 않는다. 다만 에러 UI 는 범위 밖이라 표시는 하지 않는다.
            return .none
        case .selectFilter(let index):
            state.filter = index   // TODO: 필터별 정렬 로직(최근 저장 순/코멘트 순) 후속 PR
            return .none
        case .selectRoomFilter(let index):
            // 화면이 만든 옵션 배열 밖 인덱스가 들어오는 경로(경합·잘못된 호출)도 막는다.
            state.roomFilter = min(max(0, index), state.rooms.count)
            return .none
        case .selectCategory(let index):
            state.categoryFilter = index
            return .none
        case .tapRoom(let room):
            return .navigate(.openRoomDetail(room))
        }
    }
}
