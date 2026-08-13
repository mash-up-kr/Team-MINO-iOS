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

    public init(
        rooms: [Room] = [],
        isLoading: Bool = false,
        errorMessage: String? = nil,
        selectedFilter: Int = 0,
        pins: [Pin] = [],
        currentCardIndex: Int = 0,
        pinBatches: [String: Int] = [:]
    ) {
        self.rooms = rooms
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.selectedFilter = selectedFilter
        self.pins = pins
        self.currentCardIndex = currentCardIndex
        self.pinBatches = pinBatches
    }

    /// 방이 하나도 없으면 빈상태 A (로딩 중에도 로고 유지)
    public var isEmpty: Bool { rooms.isEmpty }

    /// 현재 맨 앞 카드가 속한 방. 카드를 넘겨 다음 방 구간으로 들어가면 이 값도 그 방으로 바뀐다.
    public var currentRoom: Room? {
        guard pins.indices.contains(currentCardIndex) else { return rooms.first }
        let roomID = pins[currentCardIndex].roomID
        return rooms.first { $0.id == roomID } ?? rooms.first
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
    case tapMore(PinID)
    /// 카드 덱 하단 "이 방 장소 더 보기" 버튼 탭 (동작 미정 — 팀 논의 후 결정)
    case tapMorePlaces
}

public enum HomeNav: Equatable, Sendable {
    case goToCreateRoom
}

public typealias HomeStore = Store<HomeState, HomeAction, HomeNav>

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
            state.rooms = rooms
            state.isLoading = false
            return .run { send in
                let pins = makeMockPins(for: rooms)
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
            return .navigate(.goToCreateRoom)

        case .pinsLoaded(let pins):
            state.pins = pins
            state.currentCardIndex = 0
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

        case .tapMore:
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
