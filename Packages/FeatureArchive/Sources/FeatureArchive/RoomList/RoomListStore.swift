import Domain
import MVI

/// 방 리스트 화면 상태 — 단일 `Equatable` struct.
/// 빈/로딩/에러 UI 는 이번 범위 밖(screen.md)이라 로딩 플래그를 두지 않는다.
public struct RoomListState: Equatable {
    public var rooms: [Room]
    /// 선택된 필터 칩 인덱스(전체/최근 저장 순/코멘트 순). 정렬 로직은 미구현(UI 상태만).
    public var filter: Int
    /// 상단 필터바 좌측 드롭다운에서 고른 방 인덱스. 0 = "전체", 이후는 `rooms` 순서와 1:1.
    public var roomFilter: Int
    /// 상단 필터바 우측 카테고리 칩 인덱스(전체/카페/음식점). 필터링 로직은 미구현(UI 상태만).
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
}

/// 이번 PR 은 화면 전환이 없다(카드 탭·"+" 인터랙션 비활성) → 빈 Nav.
public enum RoomListNav: Equatable, Sendable {}

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
            return .none
        case .loadFailed:
            // 실패도 Response Action 으로 받아 흘리지 않는다. 다만 에러 UI 는 범위 밖이라 표시는 하지 않는다.
            return .none
        case .selectFilter(let index):
            state.filter = index   // TODO: 필터별 정렬 로직(최근 저장 순/코멘트 순) 후속 PR
            return .none
        case .selectRoomFilter(let index):
            state.roomFilter = index   // TODO: 선택한 방으로 지도 마커·카드 목록 좁히기 후속 PR
            return .none
        case .selectCategory(let index):
            // TODO: 카테고리 필터링 후속 PR. 현재 Domain.PinCategory 는 디자인의
            // 카페/음식점과 매핑되지 않아(worthVisiting 등) UI 상태만 둔다.
            state.categoryFilter = index
            return .none
        }
    }
}
