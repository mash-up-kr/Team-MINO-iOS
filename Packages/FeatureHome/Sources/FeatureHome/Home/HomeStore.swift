import Domain
import Foundation
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
    /// 방별 "더 보기" 재생성 배치 번호(roomID → 배치). mock 이 매번 새 식별자를 찍어 이전 카드와 겹치지 않게 한다.
    public var pinBatches: [String: Int]
    /// 방 선택 바텀 시트 표시 여부 (뱃지·캐릭터 탭으로 열림).
    public var isRoomListPresented: Bool
    /// 방 변경 직후 뜨는 툴팁에 표시할 방 이름 (nil = 숨김). 5초 후 자동으로 nil 이 된다.
    public var changedRoomToast: String?
    /// 방 리스트에서 명시적으로 고른 방 (nil = 미선택). 표시할 카드가 없을 때(빈 방들) 현재 방을 정하는 근거 —
    /// 카드가 있을 땐 덱의 맨 앞 카드가 현재 방을 정하므로 이 값은 쓰이지 않는다.
    public var selectedRoomID: String?

    public init(
        rooms: [Room] = [],
        isLoading: Bool = false,
        errorMessage: String? = nil,
        selectedFilter: Int = 0,
        pins: [Pin] = [],
        currentCardIndex: Int = 0,
        pinBatches: [String: Int] = [:],
        isRoomListPresented: Bool = false,
        changedRoomToast: String? = nil,
        selectedRoomID: String? = nil
    ) {
        self.rooms = rooms
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.selectedFilter = selectedFilter
        self.pins = pins
        self.currentCardIndex = currentCardIndex
        self.pinBatches = pinBatches
        self.isRoomListPresented = isRoomListPresented
        self.changedRoomToast = changedRoomToast
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
    case selectRoom(String)
    /// 방 변경 툴팁 숨기기 (선택 5초 후 자동 발생). 연관값은 이 타이머가 세운 방 이름 —
    /// 5초가 도는 사이 다른 방으로 바꾸면 이전 타이머가 새 방 툴팁을 지우지 않도록 방어한다.
    case dismissRoomToast(String)
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

/// 순수 reduce. UseCase 는 Effect.run 안에서만 사용한다.
public func homeReducer(
    fetchRooms: FetchRoomsUseCase
) -> (inout HomeState, HomeAction) -> Effect<HomeAction, HomeNav> {
    { state, action in
        switch action {
        case .load:
            state.isLoading = true
            state.errorMessage = nil
            state.pinBatches = [:]
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
            // 홈은 개인방(personal, "내 장소")을 먼저, 그다음 공동방(shared)을 보여준다 — 데이터 순서와
            // 무관하게 항상 이 순서. 공동방 내부 순서는 서버가 준 순서를 그대로 유지(클라 정렬 없음).
            // 뱃지·카드덱·방리스트가 모두 이 order 를 따른다(방리스트에서 개인방이 "방 만들기" 우측 고정).
            let ordered = rooms.filter { $0.type == .personal } + rooms.filter { $0.type == .shared }
            state.rooms = ordered
            // isLoading 은 여기서 끄지 않는다 — 핀까지 로드돼야 표시할 카드 유무가 정해지므로,
            // pinsLoaded 에서 끈다. (여기서 끄면 핀 도착 전 빈 상태+CTA 가 한 프레임 깜빡인다)
            return .run { send in
                let pins = makeMockPins(for: ordered)
                send(.pinsLoaded(pins))
            }

        case .loadFailed(let error):
            state.isLoading = false
            state.errorMessage = "\(error)"
            return .none

        case .selectFilter(let index):
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
            return .none

        case .tapMorePlaces:
            // 정책: "더 보기" 탭 → 현재 카드가 속한 방의 카드만 새 배치로 재생성하고 그 방의 첫 카드로 이동.
            // 다른 방 구간은 그대로 둔다. mock 은 배치 번호로 식별자를 새로 찍어(이전 카드와 id 겹침 없음)
            // 풀을 회전시켜 다른 순서로 보여준다. 실제 UseCase 는 이미 본 장소를 빼고 다음 10개를 받아온다.
            guard let room = state.currentRoom else { return .none }
            let batch = (state.pinBatches[room.id] ?? 0) + 1
            state.pinBatches[room.id] = batch
            let regenerated = makeMockPins(for: room, batch: batch)
            guard let start = state.pins.firstIndex(where: { $0.roomID == room.id }) else { return .none }
            let end = state.pins[start...].firstIndex(where: { $0.roomID != room.id }) ?? state.pins.count
            state.pins.replaceSubrange(start..<end, with: regenerated)
            state.currentCardIndex = start
            return .none

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
            state.changedRoomToast = state.rooms.first { $0.id == roomID }?.name
            return .none

        case .dismissRoomToast(let name):
            // 이 타이머가 세운 그 방 툴팁일 때만 숨긴다. 5초가 도는 사이 방을 바꾸면
            // 이전 타이머의 dismiss 가 뒤늦게 도착해 새 방 툴팁을 지우는 걸 막는다.
            if state.changedRoomToast == name {
                state.changedRoomToast = nil
            }
            return .none
        }
    }
}

// MARK: - Mock 데이터 (뷰 구현 우선, 후속 PR에서 UseCase 교체)

/// 모든 방의 카드를 방 순서대로 이어붙인 평면 배열. 앞 방 카드를 다 넘기면 다음 방 카드로 이어진다.
private func makeMockPins(for rooms: [Room]) -> [Pin] {
    rooms.flatMap { makeMockPins(for: $0, batch: 0) }
}

private func makeMockPins(for room: Room?, batch: Int = 0) -> [Pin] {
    guard let room else { return [] }
    let now = Date.now
    let categories: [PinCategory] = [
        .popularAmongFriends, .manyStories, .savedByMany, .worthVisiting,
        .popularAmongFriends, .savedByMany, .manyStories, .worthVisiting,
        .popularAmongFriends, .savedByMany,
    ]
    let places: [(String, String)] = [
        ("레이어스튜디오 10", "서울 성동구 상원4길 10"),
        ("카페 온더플랜", "서울 마포구 연남로1길 39"),
        ("을지다락", "서울 중구 을지로3가 301-19"),
        ("성수연방", "서울 성동구 연무장5가길 7"),
        ("피크닉 성수", "서울 성동구 서울숲2길 17-2"),
        ("도어투성수", "서울 성동구 성수이로 113"),
        ("라운드어바웃", "서울 마포구 양화로 162"),
        ("아보카도빌", "서울 용산구 회나무로13가길 53"),
        ("클럽 에스프레소", "서울 종로구 율곡로 83"),
        ("무드등 서울", "서울 강남구 선릉로 157길 5"),
    ]
    let count = places.count
    // 배치마다 풀을 회전시켜 다른 카드처럼 보이게 하고, id 에 배치 번호를 넣어 이전 배치와 겹치지 않게 한다.
    return (0..<count).map { i in
        let src = (i + batch) % count
        return Pin(
            id: PinID("pin-\(room.id)-\(batch)-\(i)"),
            roomID: room.id,
            category: categories[src],
            title: places[src].0,
            address: places[src].1,
            createdAt: now.addingTimeInterval(Double(-i) * 86400)
        )
    }
}
