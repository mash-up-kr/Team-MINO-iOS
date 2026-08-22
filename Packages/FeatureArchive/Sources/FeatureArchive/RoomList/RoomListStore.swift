import Core
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
    /// 공동방 생성 유도 시트(001-2-1)가 떠 있는가.
    public var isCreatePromptPresented: Bool
    /// 다음 **로드 응답 1회**는 유도 시트를 띄우지 않는다 — 만들기 화면에 다녀온 직후의 복귀.
    /// 성공·실패 어느 쪽으로 끝나든 소비된다. 실패에서 안 지우면 true 로 남아 다음 정상 진입의
    /// 시트가 조용히 안 뜬다.
    public var skipsNextCreatePrompt = false

    public init(
        rooms: [Room] = [],
        filter: Int = 0,
        roomFilter: Int = 0,
        categoryFilter: Int = 0,
        isCreatePromptPresented: Bool = false
    ) {
        self.rooms = rooms
        self.filter = filter
        self.roomFilter = roomFilter
        self.categoryFilter = categoryFilter
        self.isCreatePromptPresented = isCreatePromptPresented
    }

    /// 공동방을 하나라도 가졌는가. 빈 상태 노출과 유도 시트가 같은 기준을 봐야 해서 여기서 한 번만 정의한다.
    public var hasSharedRoom: Bool {
        rooms.contains { $0.type == .shared }
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
    case loaded([Room], isPromptSnoozed: Bool)
    case loadFailed(DomainError)   // Response Action (실패)
    case selectFilter(Int)
    case selectRoomFilter(Int)
    case selectCategory(Int)
    case tapRoom(Room)
    /// 유도 시트·빈 상태 CTA·헤더 "+" 가 공유하는 진입 액션.
    case tapCreateRoom
    /// "나중에 만들래요" — 닫고 2주 동안 다시 띄우지 않는다.
    case tapLater
    /// 시트가 닫혔다(스와이프 등). 닫기만 하고 미루지는 않는다.
    case dismissCreatePrompt
}

public enum RoomListNav: Equatable, Sendable {
    case openRoomDetail(Room)
    /// 공동방 만들기 화면으로.
    case goToCreateRoom
}

public typealias RoomListStore = Store<RoomListState, RoomListAction, RoomListNav>

/// 순수 reduce. 의존성(UseCase)은 `Effect.run` 안에서만 사용하고 시그니처는 순수하게 유지한다.
public func roomListReducer(
    useCase: FetchRoomsUseCase,
    promptSnooze: SnoozeSwitch
) -> (inout RoomListState, RoomListAction) -> Effect<RoomListAction, RoomListNav> {
    { state, action in
        switch action {
        case .load:
            return .run { send in
                do {
                    let rooms = try await useCase.execute()
                    send(.loaded(rooms, isPromptSnoozed: promptSnooze.isSnoozed))
                } catch let error as DomainError {
                    send(.loadFailed(error))
                } catch {
                    send(.loadFailed(.unknown))
                }
            }
        case .loaded(let rooms, let isPromptSnoozed):
            state.rooms = rooms
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
        case .selectFilter(let index):
            state.filter = index   // TODO: 필터별 정렬 로직(최근 저장 순/코멘트 순) 후속 PR
            return .none
        case .selectRoomFilter(let index):
            state.roomFilter = index
            return .none
        case .selectCategory(let index):
            state.categoryFilter = index
            return .none
        case .tapRoom(let room):
            return .navigate(.openRoomDetail(room))
        case .tapCreateRoom:
            state.isCreatePromptPresented = false
            state.skipsNextCreatePrompt = true
            return .navigate(.goToCreateRoom)
        // "나중에 만들래요" 만 미룬다. 스와이프로 내린 건 실수일 수 있어 2주를 걸지 않는다.
        case .tapLater:
            state.isCreatePromptPresented = false
            return .run { _ in promptSnooze.snooze() }
        case .dismissCreatePrompt:
            state.isCreatePromptPresented = false
            return .none
        }
    }
}
