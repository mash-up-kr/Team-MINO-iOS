import Domain
import MVI

/// 홈 진입 화면 상태.
public struct HomeState: Equatable {
    public var rooms: [Room]
    public var isLoading: Bool
    public var errorMessage: String?
    /// 필터바 선택 인덱스 (UI 상태만, 실제 필터 로직은 후속 PR)
    public var selectedFilter: Int
    /// 카드 덱에 표시할 핀 목록 (최대 10개)
    public var pins: [Pin]
    /// 현재 맨 앞 카드 인덱스
    public var currentCardIndex: Int
    /// 방별 "더 보기" 페이지 커서(roomID → page). 더 보기마다 +1 해 UseCase 에 넘긴다(다음 페이지 조회).
    public var roomPages: [RoomID: Int]
    /// 방 선택 바텀 시트 표시 여부 (뱃지·캐릭터 탭으로 열림).
    public var isRoomListPresented: Bool
    /// 방 변경 직후 뜨는 툴팁이 가리키는 방의 id (nil = 숨김). 5초 후 자동으로 nil 이 된다.
    /// 표시 문구(방 이름)는 뷰가 이 id 로 rooms 에서 파생한다 — 이름이 같은 방도 안정적으로 식별하려 id 로 든다.
    public var changedRoomToastID: RoomID?
    /// 방 리스트에서 명시적으로 고른 방 (nil = 미선택). 표시할 카드가 없을 때(빈 방들) 현재 방을 정하는 근거 —
    /// 카드가 있을 땐 덱의 맨 앞 카드가 현재 방을 정하므로 이 값은 쓰이지 않는다.
    public var selectedRoomID: RoomID?

    public init(
        rooms: [Room] = [],
        isLoading: Bool = false,
        errorMessage: String? = nil,
        selectedFilter: Int = 0,
        pins: [Pin] = [],
        currentCardIndex: Int = 0,
        roomPages: [RoomID: Int] = [:],
        isRoomListPresented: Bool = false,
        changedRoomToastID: RoomID? = nil,
        selectedRoomID: RoomID? = nil
    ) {
        self.rooms = rooms
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.selectedFilter = selectedFilter
        self.pins = pins
        self.currentCardIndex = currentCardIndex
        self.roomPages = roomPages
        self.isRoomListPresented = isRoomListPresented
        self.changedRoomToastID = changedRoomToastID
        self.selectedRoomID = selectedRoomID
    }

    /// 홈 빈 상태(일러스트 + "공동방 만들기" CTA)를 보여줄지. 정책: 로딩이 끝났고, 현재 정렬 기준으로
    /// 표시할 카드가 0장이면(방·공동방 유무 무관) 빈 상태다 — "방이 0개일 때"가 아니라 "볼 장소가 0일 때".
    /// (PRD [SCR-003] Flow F / [SYS-009] Flow C). CTA 는 공동방 유무와 무관하게 항상 노출한다
    /// (팀 정책 결정 — 공동방 있으면 유도를 끄는 Flow D 와는 다름).
    /// 정렬 필터 후속 PR: 이 판정은 `pins`(현재 전체) → 필터된 표시 집합 기준으로 바뀐다. [[showsRoomIdentity]] 는 계속 원본.
    public var showsEmptyState: Bool { !isLoading && pins.isEmpty }

    /// 홈 상단 방 정체성(방 칩·마스코트)을 노출할지. **표시할 장소가 있거나(정렬 무관) 공동방이 하나라도
    /// 있으면** 노출한다 → 오직 개인방만 있고 그마저 비었을 때만 로고(GGUK)·마스코트를 숨긴다.
    /// (공동방이 있으면 방이 비어도 방 리스트로 전환할 수 있어야 하므로 칩·마스코트를 유지한다)
    /// 빈 상태 본문([[showsEmptyState]]) 노출과는 독립 — 방 칩·마스코트를 띄운 채 empty state 를 보일 수 있다.
    public var showsRoomIdentity: Bool { !pins.isEmpty || rooms.contains { $0.type == .shared } }

    /// 현재 방(뱃지·방 리스트 선택 표시의 기준). 카드가 있으면 맨 앞 카드가 속한 방(넘기면 그 방으로 바뀜),
    /// 카드가 없으면(빈 방들) 방 리스트에서 고른 방(selectedRoomID) — 없으면 첫 방(내 장소).
    public var currentRoom: Room? {
        if pins.indices.contains(currentCardIndex) {
            let roomID = pins[currentCardIndex].roomID
            return rooms.first { $0.id == roomID } ?? rooms.first
        }
        return rooms.first { $0.id == selectedRoomID } ?? rooms.first
    }

    /// 현재 맨 앞 카드가 속한 방에서 (현재 카드 포함) 아직 넘기지 않은 카드 수.
    /// "이 방 장소 더 보기" 버튼 노출 판단에 쓴다 — 덱 전체가 아니라 현재 방 구간 기준이라, 방마다 끝자락에서 뜬다.
    public var remainingInCurrentRoom: Int {
        guard pins.indices.contains(currentCardIndex) else { return 0 }
        let roomID = pins[currentCardIndex].roomID
        let end = pins[currentCardIndex...].firstIndex { $0.roomID != roomID } ?? pins.count
        return end - currentCardIndex
    }
}

public enum HomeAction: Equatable {
    case load
    case loaded([Room])
    case loadFailed(DomainError)
    case selectFilter(Int)
    case tapCreateRoom
    case pinsLoaded([Pin])
    /// "이 방 장소 더 보기" 결과 — 해당 방 구간을 이 핀들로 교체한다.
    case morePlacesLoaded(roomID: RoomID, pins: [Pin])
    case swipeForward
    case swipeBackward
    case tapCard(PinID)
    /// 카드 덱 하단 "이 방 장소 더 보기" 버튼 탭 (동작 미정 — 팀 논의 후 결정)
    case tapMorePlaces
    /// 방 뱃지·캐릭터 탭 → 방 선택 바텀 시트 열기
    case tapRoomBadge
    /// 방 선택 바텀 시트 닫기 (스와이프 dismiss 포함)
    case dismissRoomList
    /// 바텀 시트에서 방 선택 → 해당 방으로 즉시 전환
    case selectRoom(RoomID)
    /// 방 변경 툴팁 숨기기 (선택 5초 후 자동 발생). 연관값은 이 타이머가 세운 방의 id —
    /// 5초가 도는 사이 다른 방으로 바꾸면 이전 타이머가 새 방 툴팁을 지우지 않도록 방어한다.
    case dismissRoomToast(RoomID)
}

public enum HomeNav: Equatable, Sendable {
    case goToCreateRoom
}

public typealias HomeStore = Store<HomeState, HomeAction, HomeNav>

// MARK: - 방 이름 표기

extension Room {
    /// 홈 표기용 이름 — 공동방은 "…방", 개인방("내 장소")은 이름 그대로. (Figma: 방 리스트·뱃지)
    var homeDisplayName: String { type == .shared ? "\(name)방" : name }
}

/// 순수 reduce. UseCase(fetchRooms·fetchPins)는 Effect.run 안에서만 사용한다.
public func homeReducer(
    fetchRooms: FetchRoomsUseCase,
    fetchPins: FetchPinsUseCase
) -> (inout HomeState, HomeAction) -> Effect<HomeAction, HomeNav> {
    { state, action in
        switch action {
        case .load:
            state.isLoading = true
            state.errorMessage = nil
            state.roomPages = [:]
            return .run { send in
                do {
                    let rooms = try await fetchRooms.execute()
                    send(.loaded(rooms))
                } catch let error as DomainError {
                    send(.loadFailed(error))
                } catch {
                    send(.loadFailed(.unknown))
                }
            }

        case .loaded(let rooms):
            // 뱃지·카드덱·방리스트가 모두 이 order 를 따른다(방리스트에서 개인방이 "방 만들기" 우측 고정).
            let ordered = RoomOrdering.personalFirst(rooms)
            state.rooms = ordered
            // isLoading 은 여기서 끄지 않는다 — 핀까지 로드돼야 표시할 카드 유무가 정해지므로,
            // pinsLoaded 에서 끈다. (여기서 끄면 핀 도착 전 빈 상태+CTA 가 한 프레임 깜빡인다)
            return .run { send in
                do {
                    send(.pinsLoaded(try await fetchPins.execute(roomIDs: ordered.map(\.id))))
                } catch let error as DomainError {
                    send(.loadFailed(error))
                } catch {
                    send(.loadFailed(.unknown))
                }
            }

        case .loadFailed(let error):
            state.isLoading = false
            // TODO: 에러 UI 미구현 — errorMessage 는 로컬 DomainError 케이스명("unknown" 등)이라 사용자 노출 불가이고,
            //   현재 화면(로딩/빈상태/덱 분기)은 이 값을 읽지 않아 실패 시 빈 화면이 된다. 에러 표시 정책(재시도 등)
            //   확정 시 사용자향 메시지로 교체하고 contentBody 에 실패 분기를 추가한다.
            state.errorMessage = "\(error)"
            return .none

        case .selectFilter(let index):
            // TODO: 필터 로직 미정 — 클라 정렬(pins 재정렬) vs 서버 재조회 중 결정 후 구현.
            //   지금은 선택 인덱스(UI 상태)만 들고, showsEmptyState/정렬 판정은 여기에 안 엮여 있다.
            state.selectedFilter = index
            return .none

        case .tapCreateRoom:
            state.isRoomListPresented = false
            return .navigate(.goToCreateRoom)

        case .pinsLoaded(let pins):
            state.pins = pins
            state.currentCardIndex = 0
            state.isLoading = false   // 핀까지 도착 → 이제 카드 유무가 확정돼 로딩 종료
            return .none

        case .morePlacesLoaded(let roomID, let newPins):
            // "더 보기" 결과를 해당 방 구간에만 splice 하고 그 방 첫 카드로 이동. 다른 방 구간은 그대로.
            // 결과가 비면(페이지 소진) 기존 카드를 지우지 않는다 — 안 그러면 그 방 덱이 통째로 사라진다.
            guard !newPins.isEmpty else { return .none }
            guard let start = state.pins.firstIndex(where: { $0.roomID == roomID }) else { return .none }
            let end = state.pins[start...].firstIndex(where: { $0.roomID != roomID }) ?? state.pins.count
            state.pins.replaceSubrange(start..<end, with: newPins)
            // FIXME(백엔드 연동): 실 API 지연 중 사용자가 다른 방으로 이동하면, 뒤늦게 온 이 응답이
            //   currentCardIndex 를 roomID 방으로 도로 끌고 간다(레이스). 실물 계약 확인 후
            //   "현재 방이 아직 roomID 일 때만 인덱스 리셋"(또는 in-flight Task 취소)으로 정리한다.
            state.currentCardIndex = start
            return .none

        case .swipeForward:
            if state.currentCardIndex < state.pins.count - 1 {
                state.currentCardIndex += 1
            }
            return .none

        case .swipeBackward:
            if state.currentCardIndex > 0 {
                state.currentCardIndex -= 1
            }
            return .none

        case .tapCard:
            // TODO: 카드 탭 동작 미정(장소 상세 진입 등) — 팀 논의 후 Nav 를 추가한다.
            return .none

        case .tapMorePlaces:
            // 정책: "더 보기" 탭 → 현재 카드가 속한 방의 다음 페이지를 받아 그 방 구간만 교체하고 그 방 첫 카드로 이동.
            // page 커서를 +1 해 UseCase 에 넘기고(mock 은 풀 회전, 실제는 이미 본 장소 뺀 다음 10개), 결과는
            // morePlacesLoaded 로 되돌려 받아 splice 한다 — 데이터 합성은 Effect.run 안에서만(reduce 순수 유지).
            // TODO: "더 보기" 소진(페이지 끝) 시 동작 미정 — 팀 논의 후 결정.
            // FIXME(백엔드 연동): page 커서를 fetch 전에 올려서, 실패해도 전진한다(다음 성공이 한 페이지 건너뜀).
            //   실 API 계약(page 번호 vs cursor 토큰, "다음 있음" 여부 응답) 확인 후 "성공 시에만 커서 확정"
            //   (실패 시 .morePlacesFailed 로 롤백)으로 정리한다. 목은 throw 안 해 지금은 무해.
            guard let room = state.currentRoom else { return .none }
            let page = (state.roomPages[room.id] ?? 0) + 1
            state.roomPages[room.id] = page
            return .run { send in
                do {
                    let pins = try await fetchPins.execute(roomID: room.id, page: page)
                    send(.morePlacesLoaded(roomID: room.id, pins: pins))
                } catch {
                    // 더 보기 실패는 조용히 무시(기존 카드 유지). 에러 UI 정책 확정 시 처리 추가.
                }
            }

        case .tapRoomBadge:
            state.isRoomListPresented = true
            return .none

        case .dismissRoomList:
            state.isRoomListPresented = false
            return .none

        case .selectRoom(let roomID):
            // 정책: 방 클릭 시 해당 방으로 바로 적용 + 시트 닫기 + 변경 툴팁.
            // 툴팁의 5초 표시 시간은 뷰(페이드 애니메이션과 함께)가 관리하고, 여기서는 상태만 세운다.
            state.isRoomListPresented = false
            state.selectedRoomID = roomID   // 카드가 없어도(빈 방) 현재 방으로 반영되도록 명시 기록
            if let start = state.pins.firstIndex(where: { $0.roomID == roomID }) {
                state.currentCardIndex = start
            }
            state.changedRoomToastID = roomID   // 식별은 id 로 — 표시 이름은 뷰가 이 id 로 파생한다
            return .none

        case .dismissRoomToast(let roomID):
            // 이 타이머가 세운 그 방 툴팁일 때만(id 일치) 숨긴다. 5초가 도는 사이 방을 바꾸면
            // 이전 타이머의 dismiss 가 뒤늦게 도착해 새 방 툴팁을 지우는 걸 막는다.
            // id 로 비교하므로 이름이 같은 방들끼리도 정확히 구분된다.
            if state.changedRoomToastID == roomID {
                state.changedRoomToastID = nil
            }
            return .none
        }
    }
}
