import Domain
import Foundation
import MVI

/// 방 상세 화면 상태. Figma `004-1-1 peek` / `004-1-2 half` / `004-1-3 full`.
///
/// `pins` 는 서버가 준 원본, `locations` 는 정렬을 적용한 표시용 목록이다. 정렬이 바뀌면 원본에서
/// 다시 계산해야 하므로 둘 다 들고 있는다 — 표시용만 들면 되돌릴 원본이 없다.
struct RoomDetailState: Equatable {
    var room: RoomDetailRoom
    var pins: [Pin]
    var locations: [RoomDetailLocation]
    /// 상단 필터바(peek·half)와 시트 툴바(full)가 함께 보는 값. 스펙 ① 기본값은 "전체".
    var sort: RoomDetailSort
    var category: RoomDetailCategory
    var viewMode: RoomDetailViewMode

    init(
        room: RoomDetailRoom,
        pins: [Pin] = [],
        locations: [RoomDetailLocation] = [],
        sort: RoomDetailSort = .all,
        category: RoomDetailCategory = .all,
        viewMode: RoomDetailViewMode = .list
    ) {
        self.room = room
        self.pins = pins
        self.locations = locations
        self.sort = sort
        self.category = category
        self.viewMode = viewMode
    }
}

enum RoomDetailAction: Equatable {
    case load
    case loaded([Pin])             // Response Action (성공)
    case loadFailed(DomainError)   // Response Action (실패)
    case selectSort(RoomDetailSort)
    case selectCategory(RoomDetailCategory)
    case selectViewMode(RoomDetailViewMode)
    case tapClose
    case tapShare(RoomDetailLocation)
}

enum RoomDetailNav: Equatable, Sendable {
    /// X 버튼 — 방 리스트로 되돌아간다. 시트 높이 단계는 껍데기가 들고 있어 그대로 승계된다(스펙 2-3).
    case close
    case shareLocation(RoomDetailLocation)
}

typealias RoomDetailStore = Store<RoomDetailState, RoomDetailAction, RoomDetailNav>

/// 순수 reduce. 의존성(UseCase)은 `Effect.run` 안에서만 쓰고 시그니처는 순수하게 유지한다.
///
/// - Parameter now: "최근 14일" 을 판정하는 기준 시각. 주입해야 정렬 테스트가 결정적이다.
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
            // 실패도 Response Action 으로 받아 흘리지 않는다. 다만 에러 UI 는 범위 밖이라 표시는 하지 않는다.
            // 기존 목록은 비우지 않는다 — 재조회 실패로 화면이 빈 리스트로 깜빡이면 안 된다.
            return .none

        case .selectSort(let sort):
            state.sort = sort
            applySort(&state, now: now())
            return .none

        case .selectCategory(let category):
            // TODO: PinCategory 가 카페·음식점과 매핑되면(스펙 ⑨ — 서버가 저장값에서 카테고리를 만든다) 목록에 반영한다.
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

/// 원본 핀에 정렬을 적용해 표시 목록을 다시 만든다. `pins` 나 `sort` 가 바뀐 직후에만 부른다.
private func applySort(_ state: inout RoomDetailState, now: Date) {
    state.locations = RoomDetailSorting.apply(state.sort, to: state.pins, now: now)
        .map(RoomDetailLocation.init(from:))
}
